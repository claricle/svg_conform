# frozen_string_literal: true
require_relative "base_remediation"

module SvgConform
  module Remediations
    # Removes explicitly disallowed attributes wherever they appear
    # (config: `attributes`, e.g. the removed-in-RFC enable-background
    # property attribute — svg_1_2_rfc's allowed_elements walk flags it
    # :not_allowed on every element carrying it).
    class DisallowedAttributeRemediation < BaseRemediation
      attribute :type, :string, default: -> { "DisallowedAttributeRemediation" }
      attribute :attributes, :string, collection: true, default: -> { [] }

      yaml do
        map "attributes", to: :attributes
      end

      def apply(document, _context)
        changes = []

        document.traverse do |node|
          next unless element?(node)

          attributes.each do |attr_name|
            next unless has_attribute?(node, attr_name)

            remove_attribute(node, attr_name)
            changes << {
              type: :attribute_removed,
              description: "Removed disallowed attribute '#{attr_name}'",
              node_name: node.name,
              attribute: attr_name,
            }
          end
        end

        changes
      end
    end
  end
end
