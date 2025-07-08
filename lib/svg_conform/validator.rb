# frozen_string_literal: true

module SvgConform
  # Main validator class for SVG conformance checking
  class Validator
    attr_reader :options

    def initialize(options = {})
      @options = {
        fix: false,
        strict: false
      }.merge(options)
    end

    # Validate an SVG file
    def validate_file(file_path, profile: :svg_1_2_rfc, **options)
      raise ValidationError, "File not found: #{file_path}" unless File.exist?(file_path)

      document = Document.from_file(file_path)
      validate_document(document, profile: profile, **options)
    end

    # Validate SVG content string
    def validate(svg_content, profile: :svg_1_2_rfc, **options)
      document = Document.from_content(svg_content)
      validate_document(document, profile: profile, **options)
    end

    # Validate a Document object
    def validate_document(document, profile: :svg_1_2_rfc, **options)
      merged_options = @options.merge(options)
      profile_obj = resolve_profile(profile)

      # Perform validation
      result = profile_obj.validate(document)

      # Apply fixes if requested
      result.apply_fixes if merged_options[:fix] && result.fixable?

      result
    end

    # Validate multiple files
    def validate_files(file_paths, profile: :svg_1_2_rfc, **options)
      results = {}

      file_paths.each do |file_path|
        results[file_path] = validate_file(file_path, profile: profile, **options)
      rescue StandardError => e
        results[file_path] = create_error_result(file_path, e)
      end

      results
    end

    # Get available profiles
    def available_profiles
      SvgConform::Profiles.available_profiles
    end

    private

    def resolve_profile(profile)
      case profile
      when Symbol, String
        SvgConform::Profiles.get(profile) || raise(ProfileError, "Unknown profile: #{profile}")
      when Profile
        profile
      else
        raise ProfileError, "Invalid profile type: #{profile.class}"
      end
    end

    def create_error_result(file_path, error)
      # Create a minimal error result for files that couldn't be processed
      OpenStruct.new(
        valid?: false,
        errors: [error],
        warnings: [],
        file_path: file_path,
        error?: true,
        to_s: -> { "Error processing #{file_path}: #{error.message}" }
      )
    end
  end
end
