# frozen_string_literal: true

require "lutaml/model"

module SvgConform
  # Individual error/warning entry in the report
  class ConformanceIssue < Lutaml::Model::Serializable
    attribute :type, :string
    attribute :requirement_id, :string
    attribute :message, :string
    attribute :element, :string
    attribute :attribute, :string
    attribute :value, :string
    attribute :line, :integer
    attribute :column, :integer
    attribute :xpath, :string
    attribute :severity, :string
    attribute :category, :string
    attribute :remediation_available, :boolean, default: -> { false }
    attribute :context, :hash, default: -> { {} }

    yaml do
      map "type", to: :type
      map "requirement_id", to: :requirement_id
      map "message", to: :message
      map "element", to: :element
      map "attribute", to: :attribute
      map "value", to: :value
      map "line", to: :line
      map "column", to: :column
      map "xpath", to: :xpath
      map "severity", to: :severity
      map "category", to: :category
      map "remediation_available", to: :remediation_available
      map "context", to: :context
    end
  end

  # Summary of issues by type
  class IssueSummary < Lutaml::Model::Serializable
    attribute :total_count, :integer
    attribute :by_requirement, :hash, default: -> { {} }
    attribute :issues, ConformanceIssue, collection: true, default: -> { [] }

    yaml do
      map "total_count", to: :total_count
      map "by_requirement", to: :by_requirement
      map "issues", to: :issues
    end
  end

  # Main conformance report structure
  class ConformanceReport < Lutaml::Model::Serializable
    attribute :filename, :string
    attribute :profile, :string
    attribute :tool, :string # "svg_conform" or "svgcheck"
    attribute :version, :string
    attribute :timestamp, :string
    attribute :valid, :boolean
    attribute :errors, IssueSummary
    attribute :warnings, IssueSummary

    yaml do
      map "filename", to: :filename
      map "profile", to: :profile
      map "tool", to: :tool
      map "version", to: :version
      map "timestamp", to: :timestamp
      map "valid", to: :valid
      map "errors", to: :errors
      map "warnings", to: :warnings
    end

    # Create report from SvgConform ValidationResult
    def self.from_svg_conform_result(filename, validation_result, profile: nil,
use_svgcheck_mapping: false)
      report = new
      report.filename = filename
      report.profile = profile
      report.tool = "svg_conform"
      report.version = SvgConform::VERSION
      report.timestamp = Time.now.iso8601
      report.valid = validation_result.valid?
      report.errors = IssueSummary.new
      report.errors.total_count = 0
      report.errors.by_requirement = {}
      report.errors.issues = []

      report.warnings = IssueSummary.new
      report.warnings.total_count = 0
      report.warnings.by_requirement = {}
      report.warnings.issues = []

      # Use SvgcheckCompatibilityEngine for svgcheck compatibility
      if use_svgcheck_mapping
        require_relative "external_checkers/svgcheck/compatibility_engine"
        compatibility_engine = ExternalCheckers::Svgcheck::CompatibilityEngine.new

        # Check if file should be treated as unparseable by svgcheck
        if compatibility_engine.should_mimic_parse_failure?(filename,
                                                            validation_result)
          # Return empty report like svgcheck does for unparseable files
          return report
        end
      end

      # Process errors (including conditional validity_errors for svgcheck compatibility)
      all_errors = validation_result.errors.dup

      # For svgcheck compatibility: include validity_errors as regular errors
      if use_svgcheck_mapping && validation_result.validity_errors.any?
        compatibility_engine ||= ExternalCheckers::Svgcheck::CompatibilityEngine.new
        all_errors.concat(validation_result.validity_errors) if compatibility_engine.should_include_validity_errors?(
          validation_result, filename
        )
      end

      if all_errors.any?
        # Filter errors using compatibility engine or use direct mapping
        filtered_errors = if use_svgcheck_mapping
                            compatibility_engine ||= ExternalCheckers::Svgcheck::CompatibilityEngine.new
                            compatibility_engine.filter_errors_for_svgcheck(
                              all_errors, filename, validation_result
                            )
                          else
                            all_errors.map do |error|
                              [error, error.requirement_id]
                            end
                          end

        error_groups = filtered_errors.group_by { |_error, req_id| req_id }

        error_groups.each do |req_id, error_pairs|
          report.errors.by_requirement[req_id] = error_pairs.length
        end

        # Update total count to reflect filtered errors
        report.errors.total_count = filtered_errors.length

        # Add ALL filtered errors (no sampling)
        report.errors.issues = filtered_errors.map do |error, mapped_req_id|
          # Extract attribute and value from error data if available
          attribute = error.data[:attribute] if error.respond_to?(:data) && error.data
          value = error.data[:value] if error.respond_to?(:data) && error.data

          issue = ConformanceIssue.new
          issue.type = "error"
          issue.requirement_id = mapped_req_id
          issue.message = error.message
          issue.element = error.element_name
          issue.attribute = attribute
          issue.value = value
          issue.line = error.line
          issue
        end
      end

      # Process warnings
      if validation_result.warnings.any?
        report.warnings.total_count = validation_result.warnings.length

        # Group by requirement_id
        warning_groups = validation_result.warnings.group_by(&:requirement_id)
        warning_groups.each do |req_id, warnings|
          report.warnings.by_requirement[req_id] = warnings.length
        end

        # Add ALL warnings (no sampling)
        report.warnings.issues = validation_result.warnings.map do |warning|
          issue = ConformanceIssue.new
          issue.type = "warning"
          issue.requirement_id = warning.requirement_id
          issue.message = warning.message
          issue.element = warning.element_name
          issue.line = warning.line
          issue
        end
      end

      report
    end

    # Create report from svgcheck error output
    def self.from_svgcheck_result(filename, error_content,
_output_content = nil)
      report = new
      report.filename = filename
      report.tool = "svgcheck"
      report.timestamp = Time.now.iso8601
      report.valid = error_content.strip.empty?
      report.errors = IssueSummary.new
      report.errors.total_count = 0
      report.errors.by_requirement = {}
      report.errors.issues = []

      report.warnings = IssueSummary.new
      report.warnings.total_count = 0
      report.warnings.by_requirement = {}
      report.warnings.issues = []

      return report if error_content.strip.empty?

      # Parse svgcheck errors using the dedicated parser
      require_relative "external_checkers/svgcheck/parser"
      parser = ExternalCheckers::Svgcheck::Parser.new
      parsed_report = parser.parse(error_content, nil, filename: filename)
      errors = parsed_report.errors.issues

      if errors.any?
        report.errors.total_count = errors.length
        report.valid = false

        # Group by type for summary
        error_groups = errors.group_by { |e| e.requirement_id || "unknown" }
        error_groups.each do |type, type_errors|
          report.errors.by_requirement[type] = type_errors.length
        end

        # Add ALL errors (no sampling)
        report.errors.issues = errors
      end

      report
    end

    # Compare two conformance reports
    def compare_with(other_report)
      differences = []

      # Compare error counts
      differences << "Error count: #{errors.total_count} vs #{other_report.errors.total_count}" if errors.total_count != other_report.errors.total_count

      # Compare warning counts
      differences << "Warning count: #{warnings.total_count} vs #{other_report.warnings.total_count}" if warnings.total_count != other_report.warnings.total_count

      # Compare error types
      all_req_ids = (errors.by_requirement.keys + other_report.errors.by_requirement.keys).uniq
      all_req_ids.each do |req_id|
        our_count = errors.by_requirement[req_id] || 0
        their_count = other_report.errors.by_requirement[req_id] || 0

        differences << "#{req_id} errors: #{our_count} vs #{their_count}" if our_count != their_count
      end

      {
        identical: differences.empty?,
        differences: differences,
        summary: differences.empty? ? "Reports are identical" : "#{differences.length} differences found",
      }
    end

    # Save report to YAML file
    def save_to_file(filepath)
      File.write(filepath, to_yaml)
    end

    # Load report from YAML file
    def self.load_from_file(filepath)
      from_yaml(File.read(filepath))
    end

    # Check if the report indicates a valid SVG
    def valid?
      valid
    end
  end
end
