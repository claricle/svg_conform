# frozen_string_literal: true

module SvgConform
  # Main validator class for SVG conformance checking
  class Validator
    attr_reader :options

    def initialize(options = {})
      @options = {
        fix: false,
        strict: false,
        mode: :sax, # Testing SAX mode
      }.merge(options)
    end

    # Validate an SVG file
    def validate_file(file_path, profile: :svg_1_2_rfc, **options)
      unless File.exist?(file_path)
        raise ValidationError,
              "File not found: #{file_path}"
      end

      merged_options = @options.merge(options)
      mode = determine_mode(file_path, merged_options[:mode])

      case mode
      when :sax
        validate_file_sax(file_path, profile: profile, **merged_options)
      when :dom
        validate_file_dom(file_path, profile: profile, **merged_options)
      end
    end

    # Validate SVG content string
    def validate(svg_content, profile: :svg_1_2_rfc, **options)
      merged_options = @options.merge(options)
      mode = merged_options[:mode]

      # Default to SAX if not specified
      mode = :sax if mode.nil?

      case mode
      when :sax
        validate_content_sax(svg_content, profile: profile, **merged_options)
      when :dom
        validate_content_dom(svg_content, profile: profile, **merged_options)
      when :auto
        # For content, we can't check file size, so default to SAX
        validate_content_sax(svg_content, profile: profile, **merged_options)
      else
        validate_content_sax(svg_content, profile: profile, **merged_options)
      end
    end

    # Validate a Document object (DOM only)
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
        results[file_path] =
          validate_file(file_path, profile: profile, **options)
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

    def determine_mode(file_path, requested_mode)
      case requested_mode
      when :sax
        :sax
      when :dom
        :dom
      when :auto
        # Use SAX for files larger than 1MB
        file_size = File.size(file_path)
        file_size > 1_000_000 ? :sax : :dom
      else
        :dom
      end
    end

    def validate_file_sax(file_path, profile:, **options)
      profile_obj = resolve_profile(profile)
      sax_doc = SvgConform::SaxDocument.from_file(file_path)
      result = sax_doc.validate_with_profile(profile_obj)

      # If fixing is requested, load DOM and apply remediations directly
      # Skip re-validation to avoid DOM performance penalty
      if options[:fix] && result.has_errors?
        dom_doc = SvgConform::Document.from_file(file_path)

        # Apply remediations directly without re-validating
        changes = profile_obj.apply_remediations(dom_doc)

        # Write fixed output if specified
        if options[:fix_output] && changes.any?
          File.write(options[:fix_output], dom_doc.to_xml)
        end

        # Return original SAX validation result (errors already detected)
        # Note: We don't re-validate to avoid DOM performance cost
      end

      result
    end

    def validate_file_dom(file_path, profile:, **options)
      document = SvgConform::Document.from_file(file_path)
      validate_document(document, profile: profile, **options)
    end

    def validate_content_sax(content, profile:, **options)
      profile_obj = resolve_profile(profile)
      sax_doc = SvgConform::SaxDocument.from_content(content)
      result = sax_doc.validate_with_profile(profile_obj)

      # If fixing is requested, convert to DOM and apply fixes
      if options[:fix] && result.has_errors?
        dom_doc = SvgConform::Document.from_content(content)
        result = validate_document(dom_doc, profile: profile_obj, **options)
      end

      result
    end

    def validate_content_dom(content, profile:, **options)
      document = SvgConform::Document.from_content(content)
      validate_document(document, profile: profile, **options)
    end

    def resolve_profile(profile)
      case profile
      when Symbol, String
        SvgConform::Profiles.get(profile) || raise(ProfileError,
                                                   "Unknown profile: #{profile}")
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
        to_s: -> { "Error processing #{file_path}: #{error.message}" },
      )
    end
  end
end
