# frozen_string_literal: true

require_relative "base_remediation"

module SvgConform
  module Remediations
    # Remediation action for font-related issues that matches svgcheck behavior
    class FontRemediation < BaseRemediation
      attribute :type, :string, default: -> { "FontRemediation" }
      attribute :default_family, :string, default: -> { "sans-serif" }
      attribute :mapping, :hash, default: -> { {} }

      def apply(document, _context)
        changes = []
        # Find all elements with font-family attributes
        document.traverse do |node|
          next unless node.respond_to?(:name) && node.name

          changes.concat(fix_font_family_attribute(node, default_family,
                                                   mapping))
          changes.concat(fix_style_font_family(node, default_family, mapping))
        end

        changes
      end

      private

      def fix_font_family_attribute(node, default_family, mapping)
        changes = []
        font_family = get_attribute(node, "font-family")
        return changes unless font_family

        new_family = convert_font_family(font_family, default_family, mapping)
        if new_family != font_family
          set_attribute(node, "font-family", new_family)
          changes << log_change(
            :attribute_modified,
            "Changed font-family from '#{font_family}' to '#{new_family}'",
            node,
          )
        end

        changes
      end

      def fix_style_font_family(node, default_family, mapping)
        changes = []
        style_value = get_attribute(node, "style")
        return changes unless style_value

        styles = parse_style(style_value)
        font_family_style = styles["font-family"]
        return changes unless font_family_style

        new_family = convert_font_family(font_family_style, default_family,
                                         mapping)
        if new_family != font_family_style
          styles["font-family"] = new_family
          new_style = build_style(styles)
          set_attribute(node, "style", new_style)
          changes << log_change(
            :attribute_modified,
            "Updated font-family in style from '#{font_family_style}' to '#{new_family}'",
            node,
          )
        end

        changes
      end

      def convert_font_family(font_family, default_family, mapping)
        # Parse font family list (can be comma-separated)
        families = font_family.split(",").map(&:strip)

        # Check if any family is valid according to svgcheck's allowed values
        valid_families = %w[serif sans-serif monospace inherit]

        converted_families = families.map do |family|
          # Remove quotes if present
          clean_family = family.gsub(/['"]/, "").strip

          # Check mapping first
          mapped = mapping[clean_family]
          return mapped if mapped

          # Check if it's already a valid family according to svgcheck
          if valid_families.include?(clean_family.downcase)
            clean_family.downcase
          else
            # svgcheck replaces any invalid font family with 'sans-serif'
            default_family
          end
        end

        # Return the first converted family or default
        converted_families.first || default_family
      end

      def parse_style(style_value)
        return {} if style_value.nil? || style_value.empty?

        styles = {}
        style_value.split(";").each do |declaration|
          next if declaration.strip.empty?

          parts = declaration.split(":", 2)
          next unless parts.size == 2

          property = parts[0].strip
          value = parts[1].strip
          styles[property] = value unless property.empty? || value.empty?
        end
        styles
      end

      def build_style(styles)
        styles.map { |prop, value| "#{prop}:#{value}" }.join(";")
      end
    end
  end
end
