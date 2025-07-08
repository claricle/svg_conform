# frozen_string_literal: true

require_relative 'validator'
require_relative 'remediation_engine'
require_relative 'document'

module SvgConform
  # Runner for applying SvgConform remediations to SVG content
  class RemediationRunner
    attr_reader :profile, :options

    def initialize(profile: :svg_1_2_rfc, options: {})
      @profile = resolve_profile(profile)
      @options = {
        verbose: false,
        strict: false
      }.merge(options)
    end

    # Run validation and remediation on SVG content
    def run_remediation(svg_content, filename: nil)
      # Parse the SVG content
      document = SvgConform::Document.from_content(svg_content)

      # Perform initial validation
      initial_validation = @profile.validate(document)

      # Create remediation engine
      remediation_engine = SvgConform::RemediationEngine.new(@profile)

      # Apply remediations if there are failures
      remediation_results = []
      if initial_validation.failed_requirements.any?
        remediation_results = remediation_engine.apply_remediations(document,
                                                                    initial_validation)
      end

      # Perform final validation after remediations
      final_validation = @profile.validate(document)

      # Create result object
      RemediationResult.new(
        filename: filename,
        original_content: svg_content,
        remediated_content: document.to_xml,
        initial_validation: initial_validation,
        final_validation: final_validation,
        remediation_results: remediation_results,
        remediation_engine: remediation_engine
      )
    end

    # Run remediation on a file
    def run_remediation_file(file_path)
      raise "File not found: #{file_path}" unless File.exist?(file_path)

      svg_content = File.read(file_path)
      filename = File.basename(file_path)

      run_remediation(svg_content, filename: filename)
    end

    # Run remediation on multiple files
    def run_remediation_batch(file_paths)
      results = {}

      file_paths.each do |file_path|
        results[file_path] = run_remediation_file(file_path)
      rescue StandardError => e
        results[file_path] = create_error_result(file_path, e)
      end

      results
    end

    # Check if profile has any remediations available
    def has_remediations?
      @profile.remediation_count.positive?
    end

    # Get available remediations for the profile
    def available_remediations
      @profile.remediations
    end

    private

    def resolve_profile(profile)
      case profile
      when Symbol, String
        SvgConform::Profiles.get(profile) || raise("Unknown profile: #{profile}")
      when SvgConform::Profile
        profile
      else
        raise "Invalid profile type: #{profile.class}"
      end
    end

    def create_error_result(file_path, error)
      RemediationResult.new(
        filename: File.basename(file_path),
        original_content: nil,
        remediated_content: nil,
        initial_validation: nil,
        final_validation: nil,
        remediation_results: [],
        remediation_engine: nil,
        error: error
      )
    end
  end

  # Result object for remediation operations
  class RemediationResult
    attr_reader :filename, :original_content, :remediated_content,
                :initial_validation, :final_validation, :remediation_results,
                :remediation_engine, :error

    def initialize(filename:, original_content:, remediated_content:,
                   initial_validation:, final_validation:, remediation_results:,
                   remediation_engine:, error: nil)
      @filename = filename
      @original_content = original_content
      @remediated_content = remediated_content
      @initial_validation = initial_validation
      @final_validation = final_validation
      @remediation_results = remediation_results
      @remediation_engine = remediation_engine
      @error = error
    end

    # Check if remediation was successful
    def success?
      @error.nil? && @final_validation&.valid?
    end

    # Check if there was an error
    def error?
      !@error.nil?
    end

    # Get the number of issues fixed
    def issues_fixed
      return 0 if @error || @initial_validation.nil? || @final_validation.nil?

      initial_errors = @initial_validation.failed_requirements.length
      final_errors = @final_validation.failed_requirements.length

      [initial_errors - final_errors, 0].max
    end

    # Get the number of remediations applied
    def remediations_applied
      @remediation_results&.length || 0
    end

    # Get successful remediations
    def successful_remediations
      return [] if @remediation_results.nil?

      @remediation_results.select(&:success?)
    end

    # Get failed remediations
    def failed_remediations
      return [] if @remediation_results.nil?

      @remediation_results.select(&:failure?)
    end

    # Check if content was modified
    def content_modified?
      return false if @original_content.nil? || @remediated_content.nil?

      normalize_content(@original_content) != normalize_content(@remediated_content)
    end

    # Get summary of changes
    def changes_summary
      return 'Error occurred' if @error
      return 'No validation performed' if @initial_validation.nil?

      if content_modified?
        "#{issues_fixed} issues fixed, #{remediations_applied} remediations applied"
      else
        'No changes needed'
      end
    end

    # Convert to hash for serialization
    def to_h
      {
        filename: @filename,
        success: success?,
        error: @error&.message,
        issues_fixed: issues_fixed,
        remediations_applied: remediations_applied,
        content_modified: content_modified?,
        changes_summary: changes_summary,
        initial_errors: @initial_validation&.failed_requirements&.length || 0,
        final_errors: @final_validation&.failed_requirements&.length || 0,
        remediation_details: @remediation_results&.map(&:to_h) || []
      }
    end

    # Generate a conformance report for the final state
    def generate_conformance_report
      return nil if @final_validation.nil? || @filename.nil?

      SvgConform::ConformanceReport.from_svg_conform_result(
        @filename,
        @final_validation,
        profile: @remediation_engine&.profile&.name || :unknown,
        use_svgcheck_mapping: true
      )
    end

    private

    def normalize_content(content)
      # Normalize whitespace and formatting for comparison
      content.gsub(/\s+/, ' ').strip
    end
  end
end
