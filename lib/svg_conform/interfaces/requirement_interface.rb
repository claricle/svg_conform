# frozen_string_literal: true

module SvgConform
  module Interfaces
    # Defines the contract for validation requirements
    #
    # All requirements must implement the methods defined in this interface.
    # This ensures consistent behavior between DOM and SAX validation modes.
    #
    # @example Implementing a requirement
    #   class MyRequirement < BaseRequirement
    #     include RequirementInterface
    #
    #     def check(node, context)
    #       # DOM validation logic here
    #     end
    #
    #     def validate_sax_element(element, context)
    #       # SAX validation logic here
    #     end
    #   end
    module RequirementInterface
      # Required Methods
      # These methods must be implemented by all requirement classes

      # Validates a single node during DOM traversal
      #
      # This is the main validation method called for each node that passes
      # the should_check_node? filter during DOM-based validation.
      #
      # @param node [Moxml::Node, Nokogiri::XML::Node] The node to validate
      # @param context [ValidationContext] The validation context for reporting errors
      # @return [void]
      # @raise [NotImplementedError] If not implemented by subclass
      #
      # @example Basic implementation
      #   def check(node, context)
      #     if invalid_condition?(node)
      #       context.add_error(
      #         requirement_id: id,
      #         message: "Node violates requirement",
      #         node: node,
      #         severity: :error,
      #       )
      #     end
      #   end
      def check(node, context)
        raise NotImplementedError, "#{self.class} must implement #check"
      end

      # Optional Methods
      # These methods have default implementations but can be overridden

      # Validates the entire document (called once per requirement)
      #
      # Default implementation traverses the document and calls #check
      # on each node that passes should_check_node?. Override for custom
      # document-level validation logic.
      #
      # @param document [Document] The document to validate
      # @param context [ValidationContext] The validation context for reporting errors
      # @return [void]
      def validate_document(document, context)
        document.traverse do |node|
          check(node, context) if should_check_node?(node, context)
        end
      end

      # Validates an element during SAX parsing
      #
      # Called for each element during streaming SAX validation.
      # Override this method to implement SAX-compatible validation logic.
      #
      # IMPORTANT: In SAX mode, the element is an ElementProxy (not a full DOM node).
      # It provides: name, attributes, parent, path, position but NOT:
      # - children (not yet parsed)
      # - tree traversal (impossible during streaming)
      # - XPath queries (not available)
      #
      # Use ElementProxy methods:
      # - element.name - element tag name
      # - element.attributes - hash of attributes
      # - element.parent - parent ElementProxy
      # - element.path - array of element names representing path
      # - element.position - 1-based position in document
      # - element.path_id - unique node ID for tracking
      #
      # @param element [ElementProxy] The element being validated
      # @param context [ValidationContext] The validation context for reporting errors
      # @return [void]
      def validate_sax_element(element, context)
        # Default: Empty - subclasses must override for SAX support
      end

      # Collects data during SAX parsing for deferred validation
      #
      # Called for each element during SAX parsing to collect data
      # that will be used later in validate_sax_complete.
      #
      # Use this for requirements that need to collect references, IDs,
      # or other data before validating (e.g., ID/reference validation).
      #
      # @param element [ElementProxy] The element being examined
      # @param context [ValidationContext] The validation context
      # @return [void]
      def collect_sax_data(element, context)
        # Default: no data collection
      end

      # Performs deferred validation after document is fully parsed
      #
      # Called once after SAX parsing completes. Use this to validate
      # relationships that require forward references (e.g., ID references,
      # cross-element constraints).
      #
      # Override this method and return true from needs_deferred_validation?
      # to enable deferred validation for this requirement.
      #
      # @param context [ValidationContext] The validation context containing
      #   collected data and for reporting errors
      # @return [void]
      def validate_sax_complete(context)
        # Default: no deferred validation
      end

      # Indicates if this requirement needs deferred validation
      #
      # Return true if this requirement needs to validate after the full
      # document is parsed (e.g., for ID/reference validation).
      #
      # When returning true, also implement validate_sax_complete.
      #
      # @return [Boolean] true if deferred validation is needed
      def needs_deferred_validation?
        false
      end

      # Determines if this requirement should check a specific node
      #
      # Return false to skip validation for a node. The default implementation
      # skips nodes that are not elements (text nodes, comments, etc.) and
      # structurally invalid nodes.
      #
      # Override this to add additional filtering logic.
      #
      # @param node [Moxml::Node, Nokogiri::XML::Node, ElementProxy] The node to check
      # @param context [ValidationContext, nil] The validation context (may be nil in some cases)
      # @return [Boolean] true if the node should be validated
      def should_check_node?(node, context = nil)
        return false unless node.respond_to?(:name) && node.respond_to?(:attributes)

        # Skip structurally invalid nodes
        return false if context&.node_structurally_invalid?(node)

        true
      end

      # Resets any state between validations (for batch mode)
      #
      # Called between validations when validating multiple files.
      # Override this method if your requirement maintains state that
      # needs to be reset.
      #
      # @return [void]
      def reset_state
        # Default: no state to reset
      end

      # Returns a string representation of the requirement
      #
      # @return [String] The requirement ID and description
      def to_s
        "#{@id}: #{@description}"
      end
    end
  end
end
