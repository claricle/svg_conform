# frozen_string_literal: true

require_relative "../node_helpers"
require_relative "../interfaces/requirement_interface"

module SvgConform
  module Requirements
    # Base class for all validation requirements
    #
    # == Validation modes
    #
    # Requirements support two validation modes:
    #
    # === DOM validation (remediation mode)
    #
    # Used when the full document is available and remediation is needed.
    # Requirements implement +validate_document+ to traverse the document once.
    #
    #   requirement.validate_document(document, context)
    #
    # === SAX validation (streaming mode)
    #
    # Used for memory-efficient streaming validation without loading the full document.
    # Requirements implement either immediate or deferred validation patterns.
    #
    # ==== Immediate validation (14 requirements)
    #
    # Validates as it encounters each node during SAX parsing.
    # No state is needed - validation is complete after +validate_sax_element+ returns.
    #
    #   def validate_sax_element(element, context)
    #     # Immediate validation logic
    #     context.add_error(...) if invalid
    #   end
    #
    # Requirements using immediate validation:
    # - AllowedElementsRequirement
    # - FontFamilyRequirement
    # - ColorRestrictionsRequirement
    # - ViewboxRequiredRequirement
    # - NamespaceRequirement
    # - IdCollectionRequirement
    # - StylePromotionRequirement
    # - NoExternalImagesRequirement
    # - NoExternalFontsRequirement
    # - NamespaceAttributesRequirement
    # - ForbiddenContentRequirement
    # - StyleRequirement
    # - LinkValidationRequirement (registers to ReferenceManifest)
    #
    # ==== Deferred validation (3 requirements)
    #
    # Collects data during SAX parsing and validates at document end.
    # Requires a nested State class to store collected data.
    #
    #   class State
    #     attr_accessor :collected_data
    #
    #     def initialize
    #       @collected_data = []
    #     end
    #   end
    #
    #   def needs_deferred_validation?
    #     true
    #   end
    #
    #   def collect_sax_data(element, context)
    #     state = context.state_for(self)
    #     state.collected_data << extract_data(element)
    #   end
    #
    #   def validate_sax_complete(context)
    #     state = context.state_for(self)
    #     # Validate collected data
    #   end
    #
    # Requirements using deferred validation:
    # - IdReferenceRequirement (needs forward references to IDs)
    # - InvalidIdReferencesRequirement (needs to collect IDs first)
    # - NoExternalCssRequirement (needs to check style elements)
    #
    # == State management
    #
    # Requirements needing deferred validation must define a nested State class.
    # The ValidationContext manages state instances per requirement via +state_for+:
    #
    #   state = context.state_for(self)  # Returns State instance for this requirement
    #
    # Each validation gets a fresh state instance, preventing state pollution when
    # reusing the same profile for multiple validations.
    class BaseRequirement < Lutaml::Model::Serializable
      include SvgConform::NodeHelpers
      include SvgConform::Interfaces::RequirementInterface

      attribute :id, :string
      attribute :description, :string
      attribute :type, :string, polymorphic_class: true, default: -> {
        self.class.name&.split("::")&.last
      }

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "type", to: :type
      end

      # Main validation method - must be implemented by subclasses
      def check(node, context)
        raise NotImplementedError, "Subclasses must implement #check"
      end

      # Validate the entire document (called once per requirement)
      def validate_document(document, context)
        document.traverse do |node|
          check(node, context) if should_check_node?(node, context)
        end
      end

      # SAX-based validation methods (NEW for streaming validation)

      # Called for each element during SAX parsing
      # Override in subclasses for immediate validation
      def validate_sax_element(element, context)
        # Default: Empty - subclasses must override for SAX support
        # Cannot call check() here as it's abstract
      end

      # Called for each element to collect data for deferred validation
      # Override in subclasses that need to collect data
      def collect_sax_data(element, context)
        # Default: no data collection
      end

      # Called at end of document for deferred validation
      # Override in subclasses that need full document data
      def validate_sax_complete(context)
        # Default: no deferred validation
      end

      # Indicates if requirement needs deferred validation
      # Override to return true for requirements that need forward references
      def needs_deferred_validation?
        false
      end

      # Determine if this requirement should check a specific node
      def should_check_node?(node, context = nil)
        return false unless node.respond_to?(:name) && node.respond_to?(:attributes)

        # Skip structurally invalid nodes (and their children are automatically skipped by marking the parent)
        return false if context&.node_structurally_invalid?(node)

        true
      end

      # Helper method to get all attributes
      # Note: Other attribute helpers are included via NodeHelpers module
      def get_attributes(node)
        return {} unless node.respond_to?(:attributes)

        attrs = node.attributes || []
        # Convert array of Moxml::Attribute objects to hash
        attrs.each_with_object({}) do |attr, hash|
          hash[attr.name] = attr.value
        end
      end

      # Shared helper for skipping attribute validation on structurally invalid nodes
      # Used by both DOM and SAX validation
      def skip_attribute_validation?(node_or_element, context)
        # For DOM mode, also check if it's an element
        return true if element?(node_or_element) && context.node_structurally_invalid?(node_or_element)

        # For SAX mode (ElementProxy always has this method)
        if node_or_element.respond_to?(:path_id)
          return context.node_structurally_invalid?(node_or_element)
        end

        false
      end

      def to_s
        "#{@id}: #{@description}"
      end
    end
  end
end
