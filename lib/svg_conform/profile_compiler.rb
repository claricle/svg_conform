# frozen_string_literal: true

require_relative "profile"

module SvgConform
  # Compiles and prepares SVG validation profiles
  # Centralizes profile loading logic for better separation of concerns
  class ProfileCompiler
    @compile_cache = {}
    @compile_mutex = Mutex.new

    class << self
      attr_reader :compile_cache, :compile_mutex

      # Compile a profile by name
      # Returns a cached profile if already compiled
      def compile(profile_id)
        profile_key = profile_id.to_s

        # Check cache (thread-safe)
        compile_mutex.synchronize do
          return compile_cache[profile_key] if compile_cache[profile_key]
        end

        # Load and compile profile
        profile = load_profile(profile_key)
        compiled_profile = prepare_profile(profile)

        # Cache result (thread-safe)
        compile_mutex.synchronize do
          compile_cache[profile_key] = compiled_profile
        end

        compiled_profile
      end

      # Compile from YAML content
      def compile_from_yaml(yaml_content)
        profile = Profile.from_yaml(yaml_content)
        prepare_profile(profile)
      end

      # Compile from file path
      def compile_from_file(file_path)
        profile = Profile.load_from_file(file_path)
        prepare_profile(profile)
      end

      # Clear compilation cache
      def clear_cache!
        compile_mutex.synchronize do
          compile_cache.clear
        end
      end

      private

      # Load profile from profiles directory
      def load_profile(profile_name)
        profile_file = File.join(Profile::PROFILES_DIR, "#{profile_name}.yml")

        unless File.exist?(profile_file)
          raise ProfileError,
                "Profile not found: #{profile_name} (expected: #{profile_file})"
        end

        Profile.load_from_file(profile_file)
      end

      # Prepare profile for use (validation and preprocessing)
      def prepare_profile(profile)
        # Validate profile has required fields
        validate_profile(profile)

        # Pre-compute requirement classifications for SAX validation
        precompute_requirement_metadata(profile)

        profile
      end

      # Validate profile structure
      def validate_profile(profile)
        if profile.name.nil? || profile.name.empty?
          raise ProfileError,
                "Profile must have a name"
        end
      end

      # Pre-compute metadata for faster validation
      def precompute_requirement_metadata(profile)
        # Trigger requirement classification to populate caches
        profile.requirements.each do |req|
          # Access classification method to populate SaxValidationHandler cache
          if req.respond_to?(:needs_deferred_validation?)
            req.needs_deferred_validation?
          end
        end
      end
    end
  end
end
