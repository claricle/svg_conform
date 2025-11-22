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

    # Validate SVG content string or document object
    # Accepts:
    # - String (XML content) → uses SAX for efficient parsing
    # - Moxml::Document or Moxml::Element → serializes once, then SAX validates
    # - Nokogiri::XML::Document or Nokogiri::XML::Element → serializes once, then SAX validates
    # - Any adapter document object (Ox, Oga, REXML, LibXML) → serializes once, then SAX validates
    #
    # IMPORTANT: Always uses SAX validation to safely handle large SVG files.
    # DOM validation can hang on large files, so we serialize once and validate with SAX.
    def validate(input, profile: :svg_1_2_rfc, **options)
      merged_options = @options.merge(options)

      # Normalize input to string, then use SAX validation
      svg_content = normalize_input_to_string(input)

      # Always use SAX mode for safe validation (handles large files)
      validate_content_sax(svg_content, profile: profile, **merged_options)
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

    # Normalize various input types to XML string
    def normalize_input_to_string(input)
      case input
      when String
        # Already a string, return as-is
        input
      else
        # Try to detect and convert document objects
        convert_document_to_string(input)
      end
    end

    # Convert document object to XML string
    def convert_document_to_string(input)
      # Check for Moxml document or element
      if input.respond_to?(:to_xml)
        return input.to_xml
      end

      # Check for Nokogiri document or element
      if defined?(Nokogiri) && input.is_a?(Nokogiri::XML::Node)
        return input.to_xml
      end

      # Check for other adapter documents that respond to to_xml
      if input.respond_to?(:to_s) && xml_like?(input)
        return input.to_s
      end

      # If we can't convert, raise an error
      raise ArgumentError,
            "Invalid input type: #{input.class}. " \
            "Expected String, Moxml document, Nokogiri document, or adapter document object. " \
            "Input must respond to #to_xml or be a valid XML string."
    end

    # Check if object looks like an XML document
    def xml_like?(obj)
      # Basic heuristic: check if it has XML-like methods
      obj.respond_to?(:name) && obj.respond_to?(:children)
    end

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
