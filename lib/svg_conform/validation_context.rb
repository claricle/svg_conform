# frozen_string_literal: true

require_relative "validation_issue"
require_relative "validation_notice"
require_relative "error_tracker"
require_relative "node_id_generator"
require_relative "structural_invalidity_tracker"
require_relative "references/reference_manifest"

module SvgConform
  # Context object passed to requirements during validation.
  #
  # Coordinates various validation concerns:
  # - Error tracking via ErrorTracker
  # - Node identification via NodeIdGenerator
  # - Structural validation via StructuralInvalidityTracker
  # - Reference tracking via ReferenceManifest
  # - Context data storage for cross-requirement communication
  class ValidationContext
    attr_reader :document, :profile, :reference_manifest

    # Initialize a new validation context
    #
    # @param document [Object] the document being validated
    # @param profile [Profile] the validation profile being used
    def initialize(document, profile)
      @document = document
      @profile = profile
      @error_tracker = ErrorTracker.new
      @node_id_generator = NodeIdGenerator.new(document)
      @structural_tracker = StructuralInvalidityTracker.new
      @data = {}
      @reference_manifest = References::ReferenceManifest.new(
        source_document: document.file_path,
      )
    end

    # Get all errors from the error tracker
    # @return [Array<ValidationIssue>] the errors
    def errors
      @error_tracker.errors
    end

    # Get all warnings from the error tracker
    # @return [Array<ValidationIssue>] the warnings
    def warnings
      @error_tracker.warnings
    end

    # Get all validity errors from the error tracker
    # @return [Array<ValidationIssue>] the validity errors
    def validity_errors
      @error_tracker.validity_errors
    end

    # Get all infos (notices) from the error tracker
    # @return [Array<ValidationNotice>] the notices
    def infos
      @error_tracker.infos
    end

    # Get all fixes from the error tracker
    # @return [Array] the fixes
    def fixes
      @error_tracker.fixes
    end

    # Mark a node as structurally invalid.
    #
    # Other requirements should skip attribute validation on these nodes.
    # Also marks all descendants as invalid since they'll be removed with the parent.
    #
    # @param node [Object] the node to mark as structurally invalid
    def mark_node_structurally_invalid(node)
      @structural_tracker.mark_node_invalid(node, @node_id_generator)
    end

    # Check if a node is structurally invalid.
    #
    # @param node [Object] the node to check
    # @return [Boolean] true if the node is structurally invalid
    def node_structurally_invalid?(node)
      @structural_tracker.node_invalid?(node, @node_id_generator)
    end

    # Add an error to the error tracker.
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
      @error_tracker.add_error(
        node: node,
        message: message,
        rule: rule,
        requirement: requirement,
        requirement_id: requirement_id,
        severity: severity,
        fix: fix,
        data: data,
      )
    end

    # Add a warning to the error tracker.
    #
    # @param rule [Object] the rule that generated the warning
    # @param node [Object] the node where the warning occurred
    # @param message [String] the warning message
    # @param fix [Object] an optional fix for the warning
    # @return [ValidationIssue] the created issue
    def add_warning(rule:, node:, message:, fix: nil)
      @error_tracker.add_warning(rule: rule, node: node, message: message, fix: fix)
    end

    # Add a fix to the error tracker.
    #
    # @param fix [Object] the fix object
    def add_fix(fix)
      @error_tracker.add_fix(fix)
    end

    # Check if context has any errors.
    # @return [Boolean] true if there are errors
    def has_errors?
      @error_tracker.has_errors?
    end

    # Check if context has any warnings.
    # @return [Boolean] true if there are warnings
    def has_warnings?
      @error_tracker.has_warnings?
    end

    # Check if context has any fixes.
    # @return [Boolean] true if there are fixes
    def has_fixes?
      @error_tracker.has_fixes?
    end

    # Get total issue count (errors + warnings).
    # @return [Integer] the total count
    def issue_count
      @error_tracker.issue_count
    end

    # Get count of fixable issues.
    # @return [Integer] the count of fixable issues
    def fixable_count
      @error_tracker.fixable_count
    end

    # Store a value in the context data.
    #
    # @param key [Symbol] the key to store under
    # @param value [Object] the value to store
    def set_data(key, value)
      @data[key] = value
    end

    # Retrieve a value from the context data.
    #
    # @param key [Symbol] the key to retrieve
    # @return [Object, nil] the stored value or nil
    def get_data(key)
      @data[key]
    end

    # Register an ID definition with the reference manifest.
    #
    # @param id_value [String] the ID value
    # @param element_name [String] the element name
    # @param line_number [Integer, nil] the line number
    # @param column_number [Integer, nil] the column number
    def register_id(id_value, element_name:, line_number: nil, column_number: nil)
      @reference_manifest.register_id(
        id_value,
        element_name: element_name,
        line_number: line_number,
        column_number: column_number,
      )
    end

    # Register a reference with the reference manifest.
    #
    # @param reference [BaseReference] the reference to register
    def register_reference(reference)
      @reference_manifest.register_reference(reference)
    end

    # Check if an ID is defined in the reference manifest.
    #
    # @param id_value [String] the ID to check
    # @return [Boolean] true if the ID is defined
    def id_defined?(id_value)
      @reference_manifest.id_defined?(id_value)
    end

    # Add a notice for external references (not errors).
    #
    # @param node [Object] the node where the notice applies
    # @param reference [Object] the reference object
    # @param message [String, nil] optional custom message
    # @return [ValidationNotice] the created notice
    def add_external_reference_notice(node:, reference:, message: nil)
      @error_tracker.add_external_reference_notice(
        node: node,
        reference: reference,
        message: message,
      )
    end

    # Generate a unique identifier for a node based on its path.
    #
    # Uses the NodeIdGenerator for path-based identification.
    #
    # @param node [Object] the node to generate an ID for
    # @return [String, nil] the node ID or nil if the node doesn't have a name
    def generate_node_id(node)
      @node_id_generator.generate_id(node)
    end

    # Get error tracker statistics.
    # @return [Hash] statistics about tracked issues
    def error_statistics
      @error_tracker.statistics
    end

    # Get structural invalidity statistics.
    # @return [Hash] statistics about structurally invalid nodes
    def structural_statistics
      {
        structurally_invalid_count: @structural_tracker.count,
        has_structural_issues: @structural_tracker.any?,
      }
    end

    # Get reference manifest statistics.
    # @return [Hash] statistics about references
    def reference_statistics
      @reference_manifest.statistics
    end

    # Get overall validation statistics.
    # @return [Hash] combined statistics
    def statistics
      {
        errors: error_statistics,
        structural: structural_statistics,
        references: reference_statistics,
      }
    end
  end
end
