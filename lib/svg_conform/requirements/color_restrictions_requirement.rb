# frozen_string_literal: true

require_relative "base_requirement"
require_relative "../css_color"

module SvgConform
  module Requirements
    # Validates color restrictions (e.g., black and white only for IETF profile)
    class ColorRestrictionsRequirement < BaseRequirement
      attribute :type, :string, default: -> { "ColorRestrictionsRequirement" }
      attribute :mode, :string, default: "black_white_only"
      attribute :allowed_colors, :string, collection: true, default: lambda {
        ["black", "white", "#000000", "#ffffff", "none", "inherit", "currentcolor"]
      }
      attribute :black_and_white_threshold, :integer, default: nil

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "type", to: :type
        map "mode", to: :mode
        map "allowed_colors", to: :allowed_colors
        map "black_and_white_threshold", to: :black_and_white_threshold
      end

      def check(node, context)
        return unless element?(node)

        # Skip attribute validation for structurally invalid nodes (e.g., wrong parent-child)
        return if context.node_structurally_invalid?(node)

        # Check color-related attributes
        color_attributes = %w[fill stroke color stop-color flood-color
                              lighting-color]

        color_attributes.each do |attr_name|
          value = get_attribute(node, attr_name)
          next if value.nil? || value.empty?

          next if valid_color?(value)

          context.add_error(
            requirement_id: id,
            message: "Color '#{value}' in attribute '#{attr_name}' is not allowed in this profile",
            node: node,
            severity: :error,
            data: {
              attribute: attr_name,
              value: value,
              element: node.name,
            },
          )
        end

        # Check style attribute for color properties
        style_value = get_attribute(node, "style")
        return unless style_value

        styles = parse_style(style_value)
        color_properties = %w[fill stroke color stop-color flood-color
                              lighting-color]

        color_properties.each do |prop|
          value = styles[prop]
          next if value.nil? || value.empty?

          next if valid_color?(value)

          context.add_error(
            requirement_id: id,
            message: "Color '#{value}' in style property '#{prop}' is not allowed in this profile",
            node: node,
            severity: :error,
            data: {
              attribute: prop,
              value: value,
              element: node.name,
            },
          )
        end
      end

      def validate_sax_element(element, context)
        # Skip attribute validation for structurally invalid nodes
        return if context.node_structurally_invalid?(element)

        # Check color-related attributes
        color_attributes = %w[fill stroke color stop-color flood-color
                              lighting-color]

        color_attributes.each do |attr_name|
          value = element.raw_attributes[attr_name]
          next if value.nil? || value.empty?

          next if valid_color?(value)

          context.add_error(
            requirement_id: id,
            message: "Color '#{value}' in attribute '#{attr_name}' is not allowed in this profile",
            node: element,
            severity: :error,
            data: {
              attribute: attr_name,
              value: value,
              element: element.name,
            },
          )
        end

        # Check style attribute for color properties
        style_value = element.raw_attributes["style"]
        return unless style_value

        styles = parse_style(style_value)
        color_properties = %w[fill stroke color stop-color flood-color
                              lighting-color]

        color_properties.each do |prop|
          value = styles[prop]
          next if value.nil? || value.empty?

          next if valid_color?(value)

          context.add_error(
            requirement_id: id,
            message: "Color '#{value}' in style property '#{prop}' is not allowed in this profile",
            node: element,
            severity: :error,
            data: {
              attribute: prop,
              value: value,
              element: element.name,
            },
          )
        end
      end

      private

      def valid_color?(color)
        # First check if threshold-based validation is enabled
        if black_and_white_threshold
          return valid_color_for_threshold?(color)
        end

        # Fall back to standard allowed colors list validation
        CssColor.allowed_in_list?(color, allowed_colors)
      end

      def valid_color_for_threshold?(color)
        # Handle special keywords that are always valid
        return true if %w[none inherit
                          currentcolor].include?(color.strip.downcase)

        # In threshold mode, be strict about exact string matching
        # Only allow the exact formats that svgcheck accepts
        allowed_colors.include?(color.strip)
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
