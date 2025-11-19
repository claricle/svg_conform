# frozen_string_literal: true

require_relative "base_requirement"

module SvgConform
  module Requirements
    # Collects all ID definitions in the document for reference validation
    class IdCollectionRequirement < BaseRequirement
      def check(node, context)
        return unless element?(node)

        id_value = get_attribute(node, "id")
        return unless id_value

        # Register the ID in the manifest
        context.register_id(
          id_value,
          element_name: node.name,
          line_number: node.respond_to?(:line) ? node.line : nil,
          column_number: node.respond_to?(:column) ? node.column : nil
        )
      end

      def validate_sax_element(element, context)
        id_value = element.raw_attributes["id"]
        return unless id_value

        # Register the ID in the manifest
        context.register_id(
          id_value,
          element_name: element.name,
          line_number: element.respond_to?(:line) ? element.line : nil,
          column_number: element.respond_to?(:column) ? element.column : nil
        )
      end
    end
  end
end