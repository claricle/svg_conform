# frozen_string_literal: true

require_relative 'base_remediation'

module SvgConform
  module Remediations
    # Remediation action for color-related issues that matches svgcheck behavior
    class ColorRemediation < BaseRemediation
      attribute :type, :string, default: -> { 'ColorRemediation' }

      DEFAULT_COLOR_THRESHOLD = 764 # Default threshold if not specified in requirement
      COLOR_DEFAULT = 'black'

      COLOR_MAP = {
        'rgb(0,0,0)' => 'black'
      }.freeze

      def apply(document, context)
        # Store the context for use in other methods
        @context = context
        @failed_requirements = context[:failed_requirements] if context.is_a?(Hash)

        changes = []

        # Find all elements with color attributes
        document.traverse do |node|
          next unless node.respond_to?(:name) && node.name

          changes.concat(fix_color_attributes(node))
          changes.concat(fix_style_colors(node))
        end

        changes
      end

      private

      def fix_color_attributes(node)
        changes = []
        color_attributes = %w[fill stroke color stop-color flood-color lighting-color]

        color_attributes.each do |attr_name|
          value = get_attribute(node, attr_name)
          next if value.nil? || value.empty?

          new_color = convert_color_value(value)
          next unless new_color != value

          set_attribute(node, attr_name, new_color)
          changes << log_change(
            :attribute_modified,
            "The attribute '#{attr_name}' does not allow the value '#{value}', replaced with '#{new_color}'",
            node
          )
        end

        changes
      end

      def fix_style_colors(node)
        changes = []
        style_value = get_attribute(node, 'style')
        return changes unless style_value

        styles = parse_style(style_value)
        color_properties = %w[fill stroke color stop-color flood-color lighting-color]
        style_changed = false

        color_properties.each do |prop|
          value = styles[prop]
          next if value.nil? || value.empty?

          new_color = convert_color_value(value)
          if new_color != value
            styles[prop] = new_color
            style_changed = true
          end
        end

        if style_changed
          new_style = build_style(styles)
          set_attribute(node, 'style', new_style)
          changes << log_change(
            :attribute_modified,
            'Updated style colors',
            node
          )
        end

        changes
      end

      def convert_color_value(color_value)
        v = color_value.strip

        # Check if it's already a valid color according to profile
        return color_value if valid_color?(v)

        # Handle grey/gray conversion - check if they're allowed, otherwise convert to default
        if %w[grey gray GREY GRAY].include?(v)
          return v if valid_color?(v) # If grey is allowed in profile, keep it

          return COLOR_DEFAULT # Otherwise convert to black to match svgcheck
        end

        # Check color map first
        return COLOR_MAP[v] if COLOR_MAP.key?(v)

        # Handle different color formats
        if v.start_with?('rgb(') && v.end_with?(')')
          convert_rgb_color(v)
        elsif v.start_with?('#')
          convert_hex_color(v)
        else
          # Unknown color, convert to default
          COLOR_DEFAULT
        end
      end

      def valid_color?(color)
        # Get allowed colors from the color restrictions requirement in failed requirements
        color_requirement = find_color_requirement
        if color_requirement.respond_to?(:allowed_colors)
          allowed_colors = color_requirement.allowed_colors
          # Check for exact case-sensitive matches first
          return true if allowed_colors.include?(color)

          # Check for case-insensitive hex color matches
          if color.match?(/^#[0-9a-fA-F]{6}$/)
            hex_allowed = allowed_colors.select { |c| c.match?(/^#[0-9a-fA-F]{6}$/) }
            return hex_allowed.any? { |allowed| allowed.downcase == color.downcase }
          end

          return false
        end

        # Fallback to default validation
        %w[black white #ffffff #000000 none inherit currentcolor].include?(color.downcase)
      end

      def find_color_requirement
        return nil unless @failed_requirements

        @failed_requirements.find do |failure|
          requirement_id = failure.requirement_id || failure.rule&.id
          requirement_id == 'color_restrictions'
        end&.rule
      end

      def convert_rgb_color(rgb_string)
        # Extract RGB values from rgb(r,g,b) or rgb(r%,g%,b%)
        match = rgb_string.match(/rgb\(([^)]+)\)/)
        return COLOR_DEFAULT unless match

        values = match[1].split(',').map(&:strip)
        return COLOR_DEFAULT unless values.length == 3

        shade = if values.first.include?('%')
                  # Percentage values
                  values.sum { |v| v.gsub('%', '').to_f * 255 / 100 }
                else
                  # Integer values
                  values.sum(&:to_i)
                end

        shade > color_threshold ? 'white' : COLOR_DEFAULT
      end

      def convert_hex_color(hex_string)
        if hex_string.length == 7 # #rrggbb
          r = hex_string[1..2].to_i(16)
          g = hex_string[3..4].to_i(16)
          b = hex_string[5..6].to_i(16)
          shade = r + g + b
        elsif hex_string.length == 4 # #rgb
          r = hex_string[1].to_i(16) * 17 # Convert single digit to double
          g = hex_string[2].to_i(16) * 17
          b = hex_string[3].to_i(16) * 17
          shade = r + g + b
        else
          return COLOR_DEFAULT
        end

        shade > color_threshold ? 'white' : COLOR_DEFAULT
      end

      def color_threshold
        # Get threshold from the color requirement configuration, fall back to default
        color_requirement = find_color_requirement
        if color_requirement.respond_to?(:black_and_white_threshold) && color_requirement.black_and_white_threshold
          color_requirement.black_and_white_threshold
        else
          DEFAULT_COLOR_THRESHOLD
        end
      end

      def parse_style(style_value)
        return {} if style_value.nil? || style_value.empty?

        styles = {}
        style_value.split(';').each do |declaration|
          next if declaration.strip.empty?

          parts = declaration.split(':', 2)
          next unless parts.size == 2

          property = parts[0].strip
          value = parts[1].strip
          styles[property] = value unless property.empty? || value.empty?
        end
        styles
      end

      def build_style(styles)
        styles.map { |prop, value| "#{prop}:#{value}" }.join(';')
      end
    end
  end
end
