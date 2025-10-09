# frozen_string_literal: true

require_relative "base_remediation"

module SvgConform
  module Remediations
    # Remediation action for viewBox-related issues that matches svgcheck behavior
    class ViewboxRemediation < BaseRemediation
      attribute :type, :string, default: -> { "ViewboxRemediation" }

      def apply(document, _context)
        changes = []

        # Get the root SVG element directly from the document
        svg_element = document.root

        if svg_element
          # Check if viewBox is missing or malformed
          current_viewbox = get_attribute(svg_element, "viewBox")

          if current_viewbox.nil? || current_viewbox.empty?
            changes.concat(add_viewbox_from_dimensions(svg_element))
          elsif current_viewbox =~ /[()]/ || current_viewbox !~ /^[\d.\s-]+$/
            # Malformed viewBox - try to fix it
            changes.concat(fix_malformed_viewbox(svg_element, current_viewbox))
          end
        end

        changes
      end

      private

      def add_viewbox_from_dimensions(svg_element)
        changes = []

        # Try to get width and height attributes (matching svgcheck logic)
        width = get_attribute(svg_element, "width")
        height = get_attribute(svg_element, "height")

        if width && height
          # Extract numeric values (svgcheck uses maybefloat function)
          width_num = extract_float(width)
          height_num = extract_float(height)

          if width_num && height_num
            # Create viewBox value: "0 0 width height" (matching svgcheck format)
            # Format numbers to avoid unnecessary decimal places
            width_formatted = width_num == width_num.to_i ? width_num.to_i.to_s : width_num.to_s
            height_formatted = height_num == height_num.to_i ? height_num.to_i.to_s : height_num.to_s
            viewbox_value = "0 0 #{width_formatted} #{height_formatted}"
            set_attribute(svg_element, "viewBox", viewbox_value)

            changes << log_change(
              :attribute_added,
              "The attribute viewBox is required on the root svg element",
              svg_element,
            )
            changes << log_change(
              :attribute_added,
              "Trying to put in the attribute with value '#{viewbox_value}'",
              svg_element,
            )
          end
        end

        changes
      end

      def extract_float(value)
        return nil unless value

        # Try to convert to float (matching svgcheck's maybefloat function)
        begin
          Float(value)
        rescue ArgumentError, TypeError
          nil
        end
      end

      def fix_malformed_viewbox(svg_element, malformed_value)
        changes = []

        # Remove parentheses and extra characters, extract numbers
        cleaned_value = malformed_value.gsub(/[()]/, "").strip

        # Split by spaces or commas and extract numeric values
        numbers = cleaned_value.split(/[\s,]+/).map do |part|
          part.gsub(/[^\d.-]/, "") # Remove non-numeric characters except . and -
        end.compact.reject(&:empty?)

        # Try to convert to valid numbers
        valid_numbers = numbers.map do |num_str|
          Float(num_str)
        rescue ArgumentError
          nil
        end.compact

        # If we have 4 valid numbers, create proper viewBox
        if valid_numbers.length == 4
          proper_viewbox = valid_numbers.join(" ")
          set_attribute(svg_element, "viewBox", proper_viewbox)

          changes << log_change(
            :attribute_modified,
            "Fixed malformed viewBox attribute from '#{malformed_value}' to '#{proper_viewbox}'",
            svg_element,
          )
        elsif valid_numbers.length >= 2
          # If we have at least width and height, use them
          width = valid_numbers[2] || valid_numbers[0]
          height = valid_numbers[3] || valid_numbers[1]
          proper_viewbox = "0 0 #{width} #{height}"
          set_attribute(svg_element, "viewBox", proper_viewbox)

          changes << log_change(
            :attribute_modified,
            "Fixed malformed viewBox attribute from '#{malformed_value}' to '#{proper_viewbox}'",
            svg_element,
          )
        end

        changes
      end
    end
  end
end
