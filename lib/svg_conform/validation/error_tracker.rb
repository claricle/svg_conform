# frozen_string_literal: true

module SvgConform
  module Validation
    # Tracks validation errors, warnings, and informational messages
    # Separated from ValidationContext for better separation of concerns
    #
    # Note: This class references ValidationContext::ValidationIssue which is
    # defined in ValidationContext. ValidationContext must be loaded first.
    class ErrorTracker
      attr_reader :errors, :warnings, :validity_errors, :infos

      def initialize
        @errors = []
        @warnings = []
        @validity_errors = []
        @infos = []
      end

      # Add an error to the context
      #
      # A declared severity of :warning is a quality advisory (see
      # TextAsPathRequirement) and must surface as a warning, not an error:
      # otherwise schema-valid documents are reported as corrupt by consumers
      # that log result.errors (metanorma, metanorma-pdfa#106). Other
      # severities keep their existing routing: :validity_error stays out of
      # the main error bucket, and :info remains in errors because the style
      # remediation flow consumes it there.
      def add_error(node:, message:, rule: nil, requirement: nil,
                     requirement_id: nil, severity: nil, fix: nil, data: {})
        # Support both old rule system and new requirements system
        rule_or_requirement = requirement || rule

        if severity == :warning
          warning = ::SvgConform::Errors::ValidationIssue.new(
            type: :warning,
            rule: rule_or_requirement,
            node: node,
            message: message,
            fix: fix,
            data: data,
            requirement_id: requirement_id,
            severity: severity,
          )
          @warnings << warning
          return warning
        end

        type, bucket = severity_bucket(severity)

        issue = ::SvgConform::Errors::ValidationIssue.new(
          type: type,
          rule: rule_or_requirement,
          node: node,
          message: message,
          fix: fix,
          data: data,
          requirement_id: requirement_id,
          severity: severity,
        )

        bucket << issue
        issue
      end

      # Map a declared severity to the issue type and tracker bucket
      def severity_bucket(severity)
        case severity
        when :validity_error
          [:error, @validity_errors]
        else
          [:error, @errors]
        end
      end

      # Add a warning to the context
      def add_warning(rule:, node:, message:, fix: nil)
        warning = ::SvgConform::Errors::ValidationIssue.new(
          type: :warning,
          rule: rule,
          node: node,
          message: message,
          fix: fix,
        )
        @warnings << warning
        warning
      end

      # Add an informational notice to the context
      def add_notice(rule:, node:, message:, fix: nil, data: {}, type: :info,
                     requirement_id: nil)
        notice = ::SvgConform::Errors::ValidationIssue.new(
          type: type,
          rule: rule,
          node: node,
          message: message,
          fix: fix,
          data: data,
          requirement_id: requirement_id,
        )
        @infos << notice
        notice
      end

      # Check if there are any errors
      def has_errors?
        @errors.any?
      end

      # Check if there are any warnings
      def has_warnings?
        @warnings.any?
      end

      # Check if there are any validity errors
      def has_validity_errors?
        @validity_errors.any?
      end

      # Get total error count (including validity errors)
      def total_error_count
        @errors.length + @validity_errors.length
      end

      # Clear all tracked issues
      def clear
        @errors.clear
        @warnings.clear
        @validity_errors.clear
        @infos.clear
      end
    end
  end
end
