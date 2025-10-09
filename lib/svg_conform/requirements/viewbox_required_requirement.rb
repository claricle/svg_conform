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

          # Add informational message about calculated viewBox if width/height are present
          width = get_attribute(root, 'width')
          height = get_attribute(root, 'height')

          if width && height && valid_number?(width) && valid_number?(height)
            calculated_viewbox = "0 0 #{width.to_f} #{height.to_f}"
            context.add_error(
              requirement: self,
              node: root,
              message: "Trying to put in the attribute with value '#{calculated_viewbox}'",
              data: {
                calculated_viewbox: calculated_viewbox,
                source_width: width,
                source_height: height
              }
            )
          end
          return
        end

        # Validate viewBox format (should be "min-x min-y width height")
        # Also accept comma-separated with parentheses like "(0, 0, 100, 100)" (svgcheck is lenient)
        normalized_viewbox = viewbox.strip.gsub(/[(),]/, ' ').squeeze(' ')
        parts = normalized_viewbox.strip.split(/\s+/)
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
