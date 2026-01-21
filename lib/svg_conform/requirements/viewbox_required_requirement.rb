# frozen_string_literal: true

require_relative "base_requirement"

module SvgConform
  module Requirements
    # Validates that SVG documents have proper viewBox attributes
    class ViewboxRequiredRequirement < BaseRequirement
      attribute :type, :string, default: -> { "ViewboxRequiredRequirement" }

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "type", to: :type
      end

      def validate_document(document, context)
        root = document.root
        return unless root&.name == "svg"

        validate_viewbox(root, context)
      end

      def validate_sax_element(element, context)
        # Only check the root SVG element
        return unless element.name == "svg" && element.parent.nil?

        validate_viewbox(element, context)
      end

      private

      # Shared validation logic for both DOM and SAX modes
      def validate_viewbox(svg_root, context)
        viewbox = get_attribute(svg_root, "viewBox")

        if viewbox.nil? || viewbox.empty?
          context.add_error(
            requirement_id: id,
            message: "SVG root element must have a viewBox attribute",
            node: svg_root,
            severity: :error,
            data: { missing_attribute: "viewBox" },
          )

          # Add informational message about calculated viewBox if width/height are present
          width = get_attribute(svg_root, "width")
          height = get_attribute(svg_root, "height")

          if width && height && valid_number?(width) && valid_number?(height)
            calculated_viewbox = "0 0 #{width.to_f} #{height.to_f}"
            context.add_error(
              requirement_id: id,
              message: "Trying to put in the attribute with value '#{calculated_viewbox}'",
              node: svg_root,
              severity: :error,
              data: {
                calculated_viewbox: calculated_viewbox,
                source_width: width,
                source_height: height,
              },
            )
          end
          return
        end

        # Validate viewBox format (should be "min-x min-y width height")
        # Also accept comma-separated with parentheses like "(0, 0, 100, 100)" (svgcheck is lenient)
        normalized_viewbox = viewbox.strip.gsub(/[(),]/, " ").squeeze(" ")
        parts = normalized_viewbox.strip.split(/\s+/)
        unless parts.length == 4 && parts.all? { |part| valid_number?(part) }
          context.add_error(
            requirement_id: id,
            message: "viewBox attribute must contain four numeric values (min-x min-y width height)",
            node: svg_root,
            severity: :error,
            data: {
              viewbox_value: viewbox,
              parsed_parts: parts,
            },
          )
          return
        end

        # Check that width and height are positive
        width = parts[2].to_f
        height = parts[3].to_f

        return unless width <= 0 || height <= 0

        context.add_error(
          requirement_id: id,
          message: "viewBox width and height must be positive values",
          node: svg_root,
          severity: :error,
          data: {
            viewbox_value: viewbox,
            width: width,
            height: height,
          },
        )
      end

      def valid_number?(str)
        Float(str)
        true
      rescue ArgumentError
        false
      end
    end
  end
end
