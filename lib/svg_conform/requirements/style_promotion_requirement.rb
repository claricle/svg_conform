# frozen_string_literal: true

module SvgConform
  module Requirements
    # Detects CSS style properties that should be promoted to attributes
    class StylePromotionRequirement < BaseRequirement
      # CSS properties that can be promoted to SVG attributes
      PROMOTABLE_PROPERTIES = %w[
        fill stroke stroke-width stroke-opacity stroke-linecap stroke-linejoin
        fill-opacity fill-rule text-anchor font-family font-size font-weight
        font-style opacity visibility display
      ].freeze

      def validate_document(document, context)
        document.xpath("//*[@style]").each do |element|
          style_attr = element["style"]
          next if style_attr.nil? || style_attr.strip.empty?

          validate_style_properties(element, style_attr, context)
        end
      end

      private

      def validate_style_properties(element, style_attr, context)
        # Parse CSS style declarations
        style_declarations = parse_style_declarations(style_attr)

        style_declarations.each do |property, value|
          next unless PROMOTABLE_PROPERTIES.include?(property)

          # Report each promotable property as an issue
          context.add_error(
            requirement_id: id,
            message: "Style property '#{property}' can be promoted to attribute",
            node: element,
            severity: :info,
            data: {
              attribute: "style",
              property: property,
              value: value,
              element: element.name,
              suggestion: "Move '#{property}:#{value}' from style to #{property} attribute",
            },
          )
        end
      end

      def parse_style_declarations(style_attr)
        declarations = {}

        # Split by semicolon and parse each declaration
        style_attr.split(";").each do |declaration|
          next if declaration.strip.empty?

          parts = declaration.split(":", 2)
          next unless parts.length == 2

          property = parts[0].strip
          value = parts[1].strip

          # Remove any trailing semicolon from value
          value = value.chomp(";")

          declarations[property] = value
        end

        declarations
      end
    end
  end
end
