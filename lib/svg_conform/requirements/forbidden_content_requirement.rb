# frozen_string_literal: true

require_relative 'base_requirement'

module SvgConform
  module Requirements
    class ForbiddenContentRequirement < BaseRequirement
      attribute :forbidden_elements, :string, collection: true, default: -> { [] }
      attribute :forbidden_attributes, :string, collection: true, default: -> { [] }

      yaml do
        map 'id', to: :id
        map 'description', to: :description
        map 'type', to: :type
        map 'forbidden_elements', to: :forbidden_elements
        map 'forbidden_attributes', to: :forbidden_attributes
      end

      def validate_document(document, context)
        document.traverse do |node|
          check(node, context) if should_check_node?(node)
        end
      end

      def check(node, context)
        return unless element?(node)

        # Check if this is a forbidden element
        if forbidden_elements.include?(node.name)
          context.add_error(
            requirement_id: id,
            message: "Forbidden element '#{node.name}' is not allowed",
            node: node,
            severity: :error
          )
        end

        # Check for forbidden attributes
        if node.respond_to?(:attributes) && node.attributes
          node.attributes.each do |attr_name, attr_value|
            name_str = attr_name.respond_to?(:name) ? attr_name.name : attr_name.to_s

            if forbidden_attributes.include?(name_str)
              context.add_error(
                requirement_id: id,
                message: "Forbidden attribute '#{name_str}' is not allowed",
                node: node,
                severity: :error
              )
            end
          end
        end
      end
    end
  end
end
