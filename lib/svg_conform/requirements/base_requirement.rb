# frozen_string_literal: true

module SvgConform
  module Requirements
    # Base class for all validation requirements
    class BaseRequirement < Lutaml::Model::Serializable
      attribute :id, :string
      attribute :description, :string
      attribute :type, :string, polymorphic_class: true, default: -> {
        self.class.name.split("::").last
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

      # Helper method to check if a node is an element
      def element?(node)
        node.respond_to?(:name) && !node.name.nil?
      end

      # Helper method to check if a node is text
      def text?(node)
        node.respond_to?(:text?) && node.text?
      end

      # Helper method to get attribute value
      def get_attribute(node, name)
        return nil unless node.respond_to?(:attribute)

        attr = node.attribute(name)
        attr&.value
      end

      # Helper method to set attribute value
      def set_attribute(node, name, value)
        return false unless node.respond_to?(:set_attribute)

        node.set_attribute(name, value)
        true
      end

      # Helper method to remove attribute
      def remove_attribute(node, name)
        return false unless node.respond_to?(:remove_attribute)

        node.remove_attribute(name)
        true
      end

      # Helper method to check if attribute exists
      def has_attribute?(node, name)
        return false unless node.respond_to?(:attribute)

        !node.attribute(name).nil?
      end

      # Helper method to get all attributes
      def get_attributes(node)
        return {} unless node.respond_to?(:attributes)

        attrs = node.attributes || []
        # Convert array of Moxml::Attribute objects to hash
        attrs.each_with_object({}) do |attr, hash|
          hash[attr.name] = attr.value
        end
      end

      def to_s
        "#{@id}: #{@description}"
      end
    end
  end
end
