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
      def add_error(node:, message:, rule: nil, requirement: nil,
                     requirement_id: nil, severity: nil, fix: nil, data: {})
        # Support both old rule system and new requirements system
        rule_or_requirement = requirement || rule

        error = ::SvgConform::Errors::ValidationIssue.new(
          type: :error,
          rule: rule_or_requirement,
          node: node,
          message: message,
          fix: fix,
          data: data,
          requirement_id: requirement_id,
          severity: severity,
        )

        # Handle special severity types
        if severity == :validity_error
          @validity_errors << error
        else
          @errors << error
        end

        error
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
      def add_notice(rule:, node:, message:, fix: nil, data: {}, type: :info)
        notice = ::SvgConform::Errors::ValidationIssue.new(
          type: type,
          rule: rule,
          node: node,
          message: message,
          fix: fix,
          data: data,
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
