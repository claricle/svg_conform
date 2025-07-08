# frozen_string_literal: true

require_relative 'base_remediation'

module SvgConform
  module Remediations
    # Promotes CSS style properties to individual attributes
    class StylePromotionRemediation < BaseRemediation
      # CSS properties that can be promoted to SVG attributes
      PROMOTABLE_PROPERTIES = %w[
        fill stroke stroke-width stroke-opacity stroke-linecap stroke-linejoin
        fill-opacity fill-rule text-anchor font-family font-size font-weight
        font-style opacity visibility display
      ].freeze

      def apply(document, context)
        results = []

        document.xpath('//*[@style]').each do |element|
          style_attr = element['style']
          next if style_attr.nil? || style_attr.strip.empty?

          promoted_properties = promote_style_properties(element, style_attr)
          promoted_properties.each do |property, value|
            results << create_promotion_result(element, property, value)
          end
        end

        results
      end

      private

      def promote_style_properties(element, style_attr)
        promoted = {}
        remaining_styles = []

        # Parse CSS style declarations
        style_declarations = parse_style_declarations(style_attr)

        style_declarations.each do |property, value|
          if PROMOTABLE_PROPERTIES.include?(property)
            # Promote to attribute
            element[property] = value
            promoted[property] = value
          else
            # Keep in style attribute
            remaining_styles << "#{property}:#{value}"
          end
        end

        # Update or remove style attribute
        if remaining_styles.empty?
          element.remove_attribute('style')
        else
          element['style'] = remaining_styles.join(';')
        end

        promoted
      end

      def parse_style_declarations(style_attr)
        declarations = {}

        # Split by semicolon and parse each declaration
        style_attr.split(';').each do |declaration|
          next if declaration.strip.empty?

          parts = declaration.split(':', 2)
          next unless parts.length == 2

          property = parts[0].strip
          value = parts[1].strip

          # Remove any trailing semicolon from value
          value = value.chomp(';')

          declarations[property] = value
        end

        declarations
      end

      def create_promotion_result(element, property, value)
        log_change(
          :style_promotion,
          "Style property '#{property}' promoted to attribute",
          element
        )
      end
    end
  end
end
