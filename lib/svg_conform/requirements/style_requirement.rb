# frozen_string_literal: true

require_relative "base_requirement"

module SvgConform
  module Requirements
    # Unified style requirement that handles all style validation:
    # - Style syntax validation
    # - Allowed style properties (whitelist/blacklist)
    # - Property value validation
    class StyleRequirement < BaseRequirement
      attribute :type, :string, default: -> { "StyleRequirement" }
      attribute :allowed_properties, :string, collection: true, default: -> {
        []
      }
      attribute :disallowed_properties, :string, collection: true, default: -> {
        []
      }
      attribute :property_values, :hash, default: -> { {} }
      attribute :property_types, :hash, default: -> { {} }

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "type", to: :type
        map "allowed_properties", to: :allowed_properties
        map "disallowed_properties", to: :disallowed_properties
        map "property_values", to: :property_values
        map "property_types", to: :property_types
      end

      def check(node, context)
        return unless element?(node)

        style_value = get_attribute(node, "style")
        return unless style_value
        return if style_value.strip.empty?

        # 1. Check for malformed style syntax
        check_malformed_syntax(style_value, node, context)

        # 2. Check for allowed/disallowed properties and validate their values
        check_style_properties(style_value, node, context)
      end

      private

      def check_malformed_syntax(style_value, node, context)
        # Check for malformed fields like ['malformed']
        if /\[['"][^'"]*['"]\]/.match?(style_value)
          context.add_error(
            requirement_id: id,
            message: "Malformed field '#{style_value.match(/\[['"][^'"]*['"]\]/)[0]}' in style attribute found. Field removed.",
            node: node,
            severity: :error,
            data: { attribute: "style", value: style_value },
          )
        end

        # Check for other malformed syntax patterns
        # Invalid property declarations without colons
        style_value.split(";").each do |declaration|
          declaration = declaration.strip
          next if declaration.empty?

          next if declaration.include?(":")

          context.add_error(
            requirement_id: id,
            message: "Malformed style declaration '#{declaration}' found. Declaration removed.",
            node: node,
            severity: :error,
            data: { attribute: "style", declaration: declaration },
          )
        end
      end

      def check_style_properties(style_value, node, context)
        style_value.split(";").each do |declaration|
          declaration = declaration.strip
          next if declaration.empty?

          next unless declaration.include?(":")

          property, value = declaration.split(":", 2).map(&:strip)
          property = property.downcase

          # Check if property is allowed
          if property_invalid?(property)
            context.add_error(
              requirement_id: id,
              message: "Style property '#{property}' removed",
              node: node,
              severity: :error,
              data: { attribute: "style", property: property },
            )
            next
          end

          # Skip value validation for color properties - handled by ColorRestrictionsRequirement
          color_properties = %w[fill stroke color stop-color flood-color
                                lighting-color]
          next if color_properties.include?(property)

          # Skip value validation for font-family - handled by FontFamilyRequirement
          next if property == "font-family"

          # Check if property value is valid
          next unless property_value_invalid?(property, value)

          context.add_error(
            requirement_id: id,
            message: "Invalid value '#{value}' for style property '#{property}'",
            node: node,
            severity: :error,
            data: { attribute: "style", property: property, value: value },
          )
        end
      end

      def property_invalid?(property)
        # If allowed_properties is specified (whitelist approach), use that
        if allowed_properties && !allowed_properties.empty?
          allowed_props = allowed_properties
          allowed_props = [allowed_props] if allowed_props.is_a?(String)
          return !allowed_props.include?(property)
        end

        # Otherwise, use disallowed_properties (blacklist approach)
        if disallowed_properties && !disallowed_properties.empty?
          disallowed_props = disallowed_properties
          disallowed_props = [disallowed_props] if disallowed_props.is_a?(String)
          return disallowed_props.include?(property)
        end

        # If neither is specified, allow all properties
        false
      end

      def property_value_invalid?(property, value)
        # First check explicit allowed values
        if property_values && property_values[property]
          allowed_values = property_values[property]
          unless allowed_values.nil? || allowed_values.empty?
            # Convert to array if it's a single value
            allowed_values = [allowed_values] if allowed_values.is_a?(String)

            # Separate literal values from type references (those starting with '<')
            literal_values = allowed_values.reject { |v| v.start_with?("<") }
            type_references = allowed_values.select { |v| v.start_with?("<") }

            # Check literal values first (case-insensitive)
            return false if literal_values.map(&:downcase).include?(value.downcase)

            # If there are type references, validate against those types
            if type_references.any?
              type_references.each do |type_ref|
                return false if validate_property_type(value, type_ref)
              end
              # Value didn't match any type reference
            else
              # No type references, and didn't match literals
            end
            return true
          end
        end

        # Then check type-based validation
        if property_types && property_types[property]
          property_type = property_types[property]
          return !validate_property_type(value, property_type)
        end

        # If no validation rules are specified, allow the value
        false
      end

      # Validate a property value against its type (from word_properties.py)
      def validate_property_type(value, type)
        case type
        when "<color>"
          validate_color_value(value)
        when "<paint>"
          validate_paint_value(value)
        when "<number>"
          validate_number_value(value)
        when "<integer>"
          validate_integer_value(value)
        else
          # Unknown type, allow it
          true
        end
      end

      # Validate color values (from basic_types['<color>'] in word_properties.py)
      def validate_color_value(value)
        allowed_colors = ["black", "#ffffff", "#FFFFFF", "white", "#000000",
                          "currentColor", "inherit"]
        # Case-insensitive comparison for all values
        allowed_colors_lower = allowed_colors.map(&:downcase)
        allowed_colors_lower.include?(value.downcase) || allowed_colors.include?(value)
      end

      # Validate paint values (from basic_types['<paint>'] in word_properties.py)
      def validate_paint_value(value)
        # <paint> includes 'none', 'currentColor', 'inherit', and <color> values
        return true if %w[none currentColor inherit].include?(value.downcase)

        # Also check if it's a valid color
        validate_color_value(value)
      end

      # Validate number values (basic numeric validation)
      def validate_number_value(value)
        # Allow numbers with optional units, decimals, percentages
        value.match?(/^[+-]?(\d+\.?\d*|\.\d+)(%|px|em|ex|pt|pc|cm|mm|in)?$/i)
      end

      # Validate integer values
      def validate_integer_value(value)
        # Allow positive/negative integers
        value.match?(/^[+-]?\d+$/)
      end
    end
  end
end
