# frozen_string_literal: true

require_relative "validation_issue"
require_relative "validation_notice"

module SvgConform
  # Tracks and manages validation issues (errors, warnings, notices).
  #
  # Provides centralized collection and querying of validation issues.
  class ErrorTracker
    attr_reader :errors, :warnings, :validity_errors, :infos, :fixes

    # Initialize a new error tracker
    def initialize
      @errors = []
      @warnings = []
      @validity_errors = []
      @infos = []
      @fixes = []
    end

    # Add an error to the tracker.
    #
    # @param node [Object] the node where the error occurred
    # @param message [String] the error message
    # @param rule [Object] the rule that was violated (deprecated)
    # @param requirement [Object] the requirement that was violated
    # @param requirement_id [String] the requirement ID
    # @param severity [Symbol] the severity level
    # @param fix [Object] an optional fix for the error
    # @param data [Hash] additional data about the error
    # @return [ValidationIssue] the created issue
    def add_error(node:, message:, rule: nil, requirement: nil,
                  requirement_id: nil, severity: nil, fix: nil, data: {})
      # Support both old rule system and new requirements system
      rule_or_requirement = requirement || rule

      error = ValidationIssue.new(
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

    # Add a warning to the tracker.
    #
    # @param rule [Object] the rule that generated the warning
    # @param node [Object] the node where the warning occurred
    # @param message [String] the warning message
    # @param fix [Object] an optional fix for the warning
    # @return [ValidationIssue] the created issue
    def add_warning(rule:, node:, message:, fix: nil)
      warning = ValidationIssue.new(
        type: :warning,
        rule: rule,
        node: node,
        message: message,
        fix: fix,
      )
      @warnings << warning
      warning
    end

    # Add an informational notice.
    #
    # Used for non-error notifications such as external references.
    #
    # @param node [Object] the node where the notice applies
    # @param reference [Object] the reference object
    # @param message [String] the notice message
    # @return [ValidationNotice] the created notice
    def add_external_reference_notice(node:, reference:, message: nil)
      notice = ValidationNotice.new(
        type: :external_reference,
        node: node,
        message: message || "External reference: #{reference.value}",
        data: { reference: reference },
      )
      @infos << notice
      notice
    end

    # Add a fix to the tracker.
    #
    # @param fix [Object] the fix object
    def add_fix(fix)
      @fixes << fix
    end

    # Check if tracker has any errors.
    # @return [Boolean] true if there are errors
    def has_errors?
      !@errors.empty?
    end

    # Check if tracker has any warnings.
    # @return [Boolean] true if there are warnings
    def has_warnings?
      !@warnings.empty?
    end

    # Check if tracker has any fixes.
    # @return [Boolean] true if there are fixes
    def has_fixes?
      !@fixes.empty?
    end

    # Get total issue count (errors + warnings).
    # @return [Integer] the total count
    def issue_count
      @errors.size + @warnings.size
    end

    # Get count of fixable issues.
    # @return [Integer] the count of fixable issues
    def fixable_count
      (@errors + @warnings).count(&:fixable?)
    end

    # Get all issues (errors and warnings).
    # @return [Array<ValidationIssue>] all issues
    def all_issues
      @errors + @warnings
    end

    # Clear all tracked errors, warnings, and notices.
    def clear
      @errors.clear
      @warnings.clear
      @validity_errors.clear
      @infos.clear
      @fixes.clear
    end

    # Get statistics about tracked issues.
    # @return [Hash] statistics
    def statistics
      {
        errors: @errors.size,
        warnings: @warnings.size,
        validity_errors: @validity_errors.size,
        infos: @infos.size,
        fixes: @fixes.size,
        total_issues: issue_count,
        fixable_count: fixable_count,
      }
    end
  end
end
