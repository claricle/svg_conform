# frozen_string_literal: true

require "set"
require_relative "document_analyzer"
require_relative "errors/validation_issue"
require_relative "errors/validation_notice"
require_relative "validation/error_tracker"
require_relative "validation/structural_invalidity_tracker"
require_relative "validation/node_id_manager"
require_relative "validation/tracker_factory"

module SvgConform
  # Context object passed to requirements during validation
  #
  # The ValidationContext serves as the central state management object
  # during SVG validation. It tracks errors, warnings, structural issues,
  # and provides helper methods for requirements to report issues.
  #
  # == Architecture
  #
  # ValidationContext delegates to specialized tracker classes:
  # - ErrorTracker: tracks errors, warnings, and notices
  # - StructuralInvalidityTracker: tracks structurally invalid nodes
  # - NodeIdManager: handles node ID generation for both SAX and DOM modes
  # - ReferenceManifest: tracks ID definitions and references
  # - State Registry: manages requirement-specific state for deferred validation
  #
  # == Validation modes
  #
  # === DOM validation (remediation mode)
  #
  #   context = ValidationContext.new(document, profile)
  #   requirement.validate_document(document, context)
  #
  # === SAX validation (streaming mode)
  #
  #   context = ValidationContext.new(nil, profile)
  #   requirement.validate_sax_element(element, context)
  #
  # == State management for deferred validation
  #
  # Requirements that need deferred validation (collecting data during SAX parsing
  # and validating at document end) use requirement-specific State classes:
  #
  #   class MyRequirement < BaseRequirement
  #     class State
  #       attr_accessor :collected_items
  #
  #       def initialize
  #         @collected_items = []
  #       end
  #     end
  #
  #     def collect_sax_data(element, context)
  #       state = context.state_for(self)
  #       state.collected_items << extract_from(element)
  #     end
  #
  #     def validate_sax_complete(context)
  #       state = context.state_for(self)
  #       # Validate state.collected_items
  #     end
  #   end
  #
  # The +state_for+ method:
  # - Returns a State instance specific to the requirement class
  # - Creates the State instance on first access (lazy initialization)
  # - Maintains one State instance per requirement class per validation
  # - Prevents state pollution when reusing profiles across validations
  #
  # Each validation gets a fresh ValidationContext with a fresh state registry,
  # ensuring that reusing the same Profile for multiple validations doesn't leak
  # state between validations.
  #
  # == Error reporting
  #
  #   context.add_error(
  #     requirement_id: id,
  #     message: "Element not allowed",
  #     node: node,
  #     severity: :error,
  #     fix: -> { remove_element(node) }
  #   )
  #
  # == Node ID tracking
  #
  # The context generates unique node IDs for tracking:
  # - SAX mode: uses pre-computed path_id from ElementProxy
  # - DOM mode: uses DocumentAnalyzer with forward-counting algorithm
  #
  # == Structural invalidity
  #
  # Requirements can mark nodes as structurally invalid (e.g., invalid
  # parent-child relationships). Other requirements should skip
  # validation on these nodes since they will be removed during remediation.
  #
  #   context.mark_node_structurally_invalid(node)
  #   context.node_structurally_invalid?(node) # => true
  class ValidationContext
    # The document being validated (nil in SAX mode)
    attr_reader :document

    # The profile containing requirements to validate against
    attr_reader :profile

    # Array of fixes that can be applied
    attr_reader :fixes

    # Reference manifest tracking IDs and references
    attr_reader :reference_manifest

    # Delegate error tracking methods to ErrorTracker
    def errors
      @error_tracker.errors
    end

    def warnings
      @error_tracker.warnings
    end

    def validity_errors
      @error_tracker.validity_errors
    end

    def infos
      @error_tracker.infos
    end

    def initialize(document, profile)
      @document = document
      @profile = profile

      # Use TrackerFactory to create all tracker instances
      trackers = Validation::TrackerFactory.create_all_trackers(document)
      @error_tracker = trackers[:error_tracker]
      @node_id_manager = trackers[:node_id_manager]
      @structural_invalidity_tracker = trackers[:structural_invalidity_tracker]
      @reference_manifest = trackers[:reference_manifest]

      @fixes = []
      @state_registry = {} # Maps requirement class => state instance
    end

    # Get or create state for a requirement
    # Each requirement gets its own state instance, preventing state pollution
    def state_for(requirement)
      @state_registry[requirement.class] ||= requirement.class::State.new
    end

    # Mark a node as structurally invalid (e.g., invalid parent-child relationship)
    # Other requirements should skip attribute validation on these nodes
    # Also marks all descendants as invalid since they'll be removed with the parent
    def mark_node_structurally_invalid(node)
      @structural_invalidity_tracker.mark_node_structurally_invalid(node)
    end

    # Mark all descendants of a node as structurally invalid
    def mark_descendants_invalid(node)
      @structural_invalidity_tracker.mark_descendants_invalid(node)
    end

    # Check if a node is structurally invalid
    def node_structurally_invalid?(node)
      @structural_invalidity_tracker.node_structurally_invalid?(node)
    end

    def add_error(node:, message:, rule: nil, requirement: nil,
requirement_id: nil, severity: nil, fix: nil, data: {})
      @error_tracker.add_error(
        node: node, message: message, rule: rule, requirement: requirement,
        requirement_id: requirement_id, severity: severity, fix: fix, data: data
      )
    end

    def add_warning(rule:, node:, message:, fix: nil)
      @error_tracker.add_warning(rule: rule, node: node, message: message,
                                 fix: fix)
    end

    # Add an informational notice (delegates to ErrorTracker)
    def add_notice(rule:, node:, message:, fix: nil, data: {})
      @error_tracker.add_notice(rule: rule, node: node, message: message,
                                fix: fix, data: data)
    end

    def add_fix(fix)
      @fixes << fix
    end

    def has_errors?
      @error_tracker.has_errors?
    end

    def has_warnings?
      @error_tracker.has_warnings?
    end

    def has_fixes?
      !@fixes.empty?
    end

    def issue_count
      @error_tracker.total_error_count + warnings.size
    end

    def fixable_count
      (@error_tracker.errors + @error_tracker.warnings).count(&:fixable?)
    end

    # Register an ID definition
    def register_id(id_value, element_name:, line_number: nil,
column_number: nil)
      @reference_manifest.register_id(
        id_value,
        element_name: element_name,
        line_number: line_number,
        column_number: column_number,
      )
    end

    # Register a reference
    def register_reference(reference)
      @reference_manifest.register_reference(reference)
    end

    # Check if ID exists in manifest
    def id_defined?(id_value)
      @reference_manifest.id_defined?(id_value)
    end

    # Add notice for external references (not errors)
    def add_external_reference_notice(node:, reference:, message: nil)
      @error_tracker.add_notice(
        rule: nil,
        node: node,
        message: message || "External reference: #{reference.value}",
        data: { reference: reference },
      )
    end

    # Generate a unique identifier for a node based on its path
    # Delegates to NodeIdManager which handles both SAX and DOM modes
    def generate_node_id(node)
      @node_id_manager.generate_node_id(node)
    end
  end
end
