# frozen_string_literal: true

require_relative "profile"

module SvgConform
  module Profiles
    PROFILES_DIR = File.expand_path("../../config/profiles", __dir__)
    @@cache = {}

    def self.get(profile_id)
      case profile_id
      when Symbol, String
        load_profile(profile_id.to_s)
      when Profile
        profile_id
      else
        raise ProfileError, "Invalid profile: #{profile_id}"
      end
    end

    def self.available_profiles
      return @@cache.keys.map(&:to_sym) if @@cache.any?

      profile_files = Dir.glob(File.join(PROFILES_DIR, "*.yml"))
      profile_files.map { |file| File.basename(file, ".yml").to_sym }
    end

    def self.load(profile_name)
      load_profile(profile_name.to_s)
    end

    def self.list
      available_profiles.map(&:to_s)
    end

    def self.clear_cache!
      @@cache.clear
    end

    def self.load_profile(profile_name)
      return @@cache[profile_name] if @@cache[profile_name]

      profile_file = File.join(PROFILES_DIR, "#{profile_name}.yml")

      unless File.exist?(profile_file)
        raise ProfileError,
              "Profile not found: #{profile_name} (expected: #{profile_file})"
      end

      begin
        profile = Profile.load_from_file(profile_file)
        @@cache[profile_name] = profile
        profile
        # rescue => e
        #   raise e
        #   raise ProfileError, "Failed to load profile #{profile_name}: #{e.message}"
      end
    end
  end
end
