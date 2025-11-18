# frozen_string_literal: true

require_relative "base_requirement"

module SvgConform
  module Requirements
    # Validates font family restrictions
    class FontFamilyRequirement < BaseRequirement
      attribute :type, :string, default: -> { "FontFamilyRequirement" }
      attribute :allowed_families, :string, collection: true, default: -> {
        %w[serif sans-serif monospace]
      }
      attribute :svgcheck_compatibility, :boolean, default: -> { false }
      attribute :enable_fallback, :boolean, default: -> { false }
      attribute :default_fallback, :string, default: -> { "sans-serif" }

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "type", to: :type
        map "allowed_families", to: :allowed_families
        map "svgcheck_compatibility", to: :svgcheck_compatibility
        map "enable_fallback", to: :enable_fallback
        map "default_fallback", to: :default_fallback
      end

      def check(node, context)
        return unless element?(node)

        # Check font-family attribute only (not style properties)
        # Style properties are handled by StylePromotionRequirement to avoid duplication
        font_family = get_attribute(node, "font-family")
        return unless font_family

        if svgcheck_compatibility
          check_font_family_svgcheck_mode(node, context, font_family,
                                          "font-family")
        elsif !valid_font_family?(font_family)
          context.add_error(
            requirement_id: id,
            message: "Font family '#{font_family}' is not allowed in this profile",
            node: node,
            severity: :error,
            data: { attribute: "font-family", value: font_family },
          )
        end
      end

      def validate_sax_element(element, context)
        # Check font-family attribute only
        font_family = element.raw_attributes["font-family"]
        return unless font_family

        if svgcheck_compatibility
          check_font_family_svgcheck_mode(element, context, font_family, "font-family")
        elsif !valid_font_family?(font_family)
          context.add_error(
            requirement_id: id,
            message: "Font family '#{font_family}' is not allowed in this profile",
            node: element,
            severity: :error,
            data: { attribute: "font-family", value: font_family }
          )
        end
      end

      private

      def check_font_family_svgcheck_mode(node, context, font_family_value,
attribute_name)
        # Check if the font family value is valid according to svgcheck
        return if valid_font_family_svgcheck?(font_family_value)

        # Generate error message matching svgcheck's exact format
        context.add_error(
          requirement_id: id,
          message: "The attribute '#{attribute_name}' does not allow the value '#{font_family_value}', replaced with '#{default_fallback}'",
          node: node,
          severity: :error,
          data: {
            attribute: attribute_name,
            original_value: font_family_value,
            replacement_value: default_fallback,
          },
        )
      end

      def extract_valid_fonts(font_family_value)
        # Parse font family list (comma-separated)
        families = font_family_value.split(",").map(&:strip)

        valid_fonts = []
        families.each do |family|
          # Remove quotes if present
          clean_family = family.gsub(/['"]/, "").strip.downcase
          valid_fonts << clean_family if allowed_families.include?(clean_family)
        end

        valid_fonts
      end

      def valid_font_family_svgcheck?(font_family)
        # svgcheck allows: serif, sans-serif, monospace, inherit
        # Any other value is considered invalid and gets replaced with sans-serif
        svgcheck_allowed = %w[serif sans-serif monospace inherit]

        # Parse font family list (can be comma-separated)
        families = font_family.split(",").map(&:strip)

        # Check if any family in the list is valid
        families.any? do |family|
          # Remove quotes if present
          clean_family = family.gsub(/['"]/, "").strip.downcase
          svgcheck_allowed.include?(clean_family)
        end
      end

      def valid_font_family?(font_family)
        # Parse font family list (can be comma-separated)
        families = font_family.split(",").map(&:strip)

        # All families must be allowed (matching svgcheck behavior)
        families.all? do |family|
          # Remove quotes if present
          clean_family = family.gsub(/['"]/, "").strip.downcase
          allowed_families.include?(clean_family)
        end
      end

      def parse_style(style_string)
        return {} if style_string.nil? || style_string.empty?

        properties = {}
        declarations = style_string.split(";").map(&:strip)

        declarations.each do |declaration|
          next if declaration.empty?

          parts = declaration.split(":", 2)
          next unless parts.length == 2

          property = parts[0].strip
          value = parts[1].strip
          properties[property] = value
        end

        properties
      end
    end
  end
end
