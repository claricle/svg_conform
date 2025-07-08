# frozen_string_literal: true

require 'json'

module SvgConform
  # Represents the result of validating an SVG document
  class ValidationResult
    attr_reader :document, :profile, :errors, :warnings, :validity_errors, :fixes_applied, :fixed_document

    def initialize(document, profile, context)
      @document = document
      @profile = profile
      @errors = context.errors
      @warnings = context.warnings
      @validity_errors = context.validity_errors
      @fixes_applied = []
      @fixed_document = nil
    end

    def valid?
      @errors.empty? && @validity_errors.empty?
    end

    def has_errors?
      !@errors.empty?
    end

    def has_warnings?
      !@warnings.empty?
    end

    def fixable?
      (@errors + @warnings).any?(&:fixable?)
    end

    def fixed?
      !@fixed_document.nil?
    end

    def error_count
      @errors.size
    end

    def warning_count
      @warnings.size
    end

    def issue_count
      error_count + warning_count
    end

    def fixable_count
      (@errors + @warnings).count(&:fixable?)
    end

    def failed_requirements
      @errors.select(&:requirement_id)
    end

    def apply_fixes
      return self unless fixable?

      # Create a copy of the document for fixing
      @fixed_document = @document.dup
      @fixes_applied = []

      # Apply fixes for errors first, then warnings
      fixable_issues = (@errors + @warnings).select(&:fixable?)

      fixable_issues.each do |issue|
        @fixes_applied << issue if issue.apply_fix
      end

      self
    end

    def to_s(format: :text)
      case format
      when :text
        to_text
      when :json
        to_json
      when :hash
        to_h
      else
        to_text
      end
    end

    def to_h
      {
        file: @document.file_path,
        profile: @profile.name,
        valid: valid?,
        errors: @errors.map(&:to_h),
        warnings: @warnings.map(&:to_h),
        fixes_applied: @fixes_applied.size,
        fixable: fixable_count
      }
    end

    def to_json(*args)
      JSON.pretty_generate(to_h, *args)
    end

    private

    def to_text
      lines = []
      lines << 'SVG Conformance Report'
      lines << '=' * 22
      lines << ''
      lines << "File: #{@document.file_path || 'inline'}"
      lines << "Profile: #{@profile.name} (#{@profile.description})"
      lines << "Status: #{valid? ? 'VALID' : 'INVALID'}"
      lines << ''

      if has_errors?
        lines << "Errors (#{error_count}):"
        @errors.each_with_index do |error, i|
          lines << "  #{i + 1}. #{error}"
        end
        lines << ''
      end

      if has_warnings?
        lines << "Warnings (#{warning_count}):"
        @warnings.each_with_index do |warning, i|
          lines << "  #{i + 1}. #{warning}"
        end
        lines << ''
      end

      if fixable?
        lines << "Fixes Available: #{fixable_count}"
        lines << "Fixes Applied: #{@fixes_applied.size}" if fixed?
        lines << ''
      end

      lines << "✓ Document is valid and conforms to the #{@profile.name} profile." if valid? && !has_warnings?

      lines.join("\n")
    end
  end
end
