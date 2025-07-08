# frozen_string_literal: true

require_relative 'base_requirement'

module SvgConform
  module Requirements
    # Validates that SVG documents have proper viewBox attributes
    class ViewboxRequiredRequirement < BaseRequirement
      attribute :type, :string, default: -> { 'ViewboxRequiredRequirement' }

      yaml do
        map 'id', to: :id
        map 'description', to: :description
        map 'type', to: :type
      end

      def validate_document(document, context)
        root = document.root
        return unless root&.name == 'svg'

        viewbox = get_attribute(root, 'viewBox')

        if viewbox.nil? || viewbox.empty?
          context.add_error(
            requirement: self,
            node: root,
            message: 'SVG root element must have a viewBox attribute',
            data: { missing_attribute: 'viewBox' }
          )
          return
        end

        # Validate viewBox format (should be "min-x min-y width height")
        parts = viewbox.strip.split(/\s+/)
        unless parts.length == 4 && parts.all? { |part| valid_number?(part) }
          context.add_error(
            requirement: self,
            node: root,
            message: 'viewBox attribute must contain four numeric values (min-x min-y width height)',
            data: {
              viewbox_value: viewbox,
              parsed_parts: parts
            }
          )
          return
        end

        # Check that width and height are positive
        width = parts[2].to_f
        height = parts[3].to_f

        return unless width <= 0 || height <= 0

        context.add_error(
          requirement: self,
          node: root,
          message: 'viewBox width and height must be positive values',
          data: {
            viewbox_value: viewbox,
            width: width,
            height: height
          }
        )
      end

      private

      def valid_number?(str)
        Float(str)
        true
      rescue ArgumentError
        false
      end
    end
  end
end
