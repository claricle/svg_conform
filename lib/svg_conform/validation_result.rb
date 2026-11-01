# frozen_string_literal: true

require "json"

module SvgConform
  # Represents the result of validating an SVG document
  class ValidationResult
    attr_reader :document, :profile, :errors, :warnings, :validity_errors,
                :infos, :fixes_applied, :fixed_document, :reference_manifest

    def initialize(document, profile, context)
      @document = document
      @profile = profile
      @errors = context.errors
      @warnings = context.warnings
      @validity_errors = context.validity_errors
      @infos = context.infos
      @fixes_applied = []
      @fixed_document = nil
      @reference_manifest = context.reference_manifest
    end

    def valid?
      @errors.empty? && @validity_errors.empty?
    end

    # True for errors and validity errors, matching valid?.
    def has_errors?
      error_count.positive?
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

    # Errors plus validity errors: both are "error" in the canonical report.
    def error_count
      @errors.size + @validity_errors.size
    end

    def warning_count
      @warnings.size
    end

    def info_count
      @infos.size
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

    # Convenience accessors for manifest data
    def available_ids
      @reference_manifest.available_ids
    end

    def internal_references
      @reference_manifest.internal_references
    end

    def external_references
      @reference_manifest.external_references
    end

    def has_external_references?
      !@reference_manifest.external_references.empty?
    end

    def unresolved_internal_references
      @reference_manifest.unresolved_internal_references
    end

    def reference_statistics
      @reference_manifest.statistics
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

    # The canonical LensCore::Report for this result (schema version 1).
    # The timestamp is only included when the caller supplies one.
    # Raises when the optional lens_core gem is not installed.
    def to_lens_core_report(timestamp: nil)
      unless SvgConform.lens_core_available?
        raise SvgConform::Error,
              "lens_core is not installed; the canonical diagnostics " \
              "report requires it"
      end
      Diagnostics::LensCoreAdapter.call(self, timestamp: timestamp)
    end

    # Report as a symbol-keyed Hash: the canonical LensCore shape (with
    # the compatibility extensions +file+, +fixes_applied+, +fixable+ and
    # +reference_manifest+) when lens_core is installed, else the plain
    # structural shape.
    def to_h
      if SvgConform.lens_core_available?
        JSON.parse(to_json, symbolize_names: true)
      else
        structural_h
      end
    end

    # Canonical LensCore JSON when lens_core is installed, else the plain
    # structural serialization.
    def to_json(*)
      if SvgConform.lens_core_available?
        LensCore::Renderers::Json.render(compatibility_report).chomp
      else
        JSON.pretty_generate(structural_h)
      end
    end

    def to_yaml(*)
      if SvgConform.lens_core_available?
        LensCore::Renderers::Yaml.render(compatibility_report)
      else
        structural_h.to_yaml
      end
    end

    # Export manifest separately for detailed analysis
    def export_manifest(format: :yaml)
      case format
      when :yaml
        @reference_manifest.to_yaml
      when :json
        @reference_manifest.to_json
      when :hash
        @reference_manifest.to_h
      else
        @reference_manifest.to_yaml
      end
    end

    private

    def compatibility_report(timestamp: nil)
      report = to_lens_core_report(timestamp: timestamp)
      extensions = report.extensions.merge(
        "fixes_applied" => @fixes_applied.size,
        "fixable" => fixable_count,
        "reference_manifest" => Diagnostics::LensCoreAdapter.json_value(
          @reference_manifest.to_h, "reference_manifest"
        ),
      )
      LensCore::Report.new(
        producer: report.producer, profile: report.profile,
        valid: report.valid, diagnostics: report.diagnostics,
        timestamp: report.timestamp, extensions: extensions
      )
    end

    def to_text
      if SvgConform.lens_core_available?
        lines = [LensCore::Renderers::Human.render(to_lens_core_report).chomp]
        if fixable?
          lines << ""
          lines << "Fixes Available: #{fixable_count}"
          lines << "Fixes Applied: #{@fixes_applied.size}" if fixed?
        end
        return lines.join("\n")
      end

      lines = []
      lines << "SVG Conformance Report"
      lines << ("=" * 22)
      lines << ""
      lines << "File: #{@document.file_path || 'inline'}"
      lines << "Profile: #{@profile.name} (#{@profile.description})"
      lines << "Status: #{valid? ? 'VALID' : 'INVALID'}"
      lines << ""

      if has_errors?
        lines << "Errors (#{error_count}):"
        @errors.each_with_index do |error, i|
          lines << "  #{i + 1}. #{error}"
        end
        lines << ""
      end

      if has_warnings?
        lines << "Warnings (#{warning_count}):"
        @warnings.each_with_index do |warning, i|
          lines << "  #{i + 1}. #{warning}"
        end
        lines << ""
      end

      if fixable?
        lines << "Fixes Available: #{fixable_count}"
        lines << "Fixes Applied: #{@fixes_applied.size}" if fixed?
        lines << ""
      end

      if valid? && !has_warnings?
        lines << "✓ Document is valid and conforms to the #{@profile.name} profile."
      end

      lines.join("\n")
    end

    # The plain structural shape (the 0.2.4 serialization), used when the
    # optional lens_core renderer is not installed.
    def structural_h
      {
        file: @document&.file_path,
        profile: @profile.name,
        valid: valid?,
        errors: @errors.map(&:to_h),
        warnings: @warnings.map(&:to_h),
        fixes_applied: @fixes_applied.size,
        fixable: fixable_count,
        reference_manifest: @reference_manifest.to_h,
      }
    end
  end
end
