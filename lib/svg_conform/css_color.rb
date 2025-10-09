# frozen_string_literal: true

module SvgConform
  # Handles CSS color equivalence, normalization, and conversion
  class CssColor
    # Named colors mapping to their hex equivalents
    NAMED_COLORS = {
      "black" => "#000000",
      "white" => "#ffffff",
      "red" => "#ff0000",
      "green" => "#008000",
      "blue" => "#0000ff",
      "yellow" => "#ffff00",
      "cyan" => "#00ffff",
      "magenta" => "#ff00ff",
      "silver" => "#c0c0c0",
      "gray" => "#808080",
      "grey" => "#808080",
      "maroon" => "#800000",
      "olive" => "#808000",
      "lime" => "#00ff00",
      "aqua" => "#00ffff",
      "teal" => "#008080",
      "navy" => "#000080",
      "fuchsia" => "#ff00ff",
      "purple" => "#800080",
    }.freeze

    # Reverse mapping for canonical named color lookup
    HEX_TO_NAMED = NAMED_COLORS.invert.freeze

    # CSS color keywords that have special meaning
    SPECIAL_KEYWORDS = %w[inherit currentcolor transparent none].freeze

    class << self
      # Normalize a color to its canonical hex representation
      def normalize(color)
        return nil if color.nil? || color.empty?

        color = color.strip.downcase

        # Handle special keywords
        return color if SPECIAL_KEYWORDS.include?(color)

        # Handle named colors
        return NAMED_COLORS[color] if NAMED_COLORS.key?(color)

        # Handle hex colors
        if color.match?(/^#[0-9a-f]{3}$/)
          # Expand short hex: #fff → #ffffff
          return expand_short_hex(color)
        elsif color.match?(/^#[0-9a-f]{6}$/)
          # Already normalized 6-digit hex
          return color
        end

        # Handle RGB functions with integers
        rgb_match = color.match(/^rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)$/)
        if rgb_match
          r, g, b = rgb_match[1..3].map(&:to_i)
          return rgb_to_hex(r, g, b)
        end

        # Handle RGB functions with percentages
        rgb_percent_match = color.match(/^rgb\s*\(\s*(\d+(?:\.\d+)?)%\s*,\s*(\d+(?:\.\d+)?)%\s*,\s*(\d+(?:\.\d+)?)%\s*\)$/)
        if rgb_percent_match
          r = (rgb_percent_match[1].to_f * 255 / 100).round
          g = (rgb_percent_match[2].to_f * 255 / 100).round
          b = (rgb_percent_match[3].to_f * 255 / 100).round
          return rgb_to_hex(r, g, b)
        end

        # Handle mixed RGB functions (percentage and absolute values)
        rgb_mixed_match = color.match(/^rgb\s*\(\s*(\d+(?:\.\d+)?%?)\s*,\s*(\d+(?:\.\d+)?%?)\s*,\s*(\d+(?:\.\d+)?%?)\s*\)$/)
        if rgb_mixed_match
          r = parse_rgb_value(rgb_mixed_match[1])
          g = parse_rgb_value(rgb_mixed_match[2])
          b = parse_rgb_value(rgb_mixed_match[3])
          return rgb_to_hex(r, g, b)
        end

        # Handle RGBA functions (ignore alpha for SVG purposes)
        rgba_match = color.match(/^rgba\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*[\d.]+\s*\)$/)
        if rgba_match
          r, g, b = rgba_match[1..3].map(&:to_i)
          return rgb_to_hex(r, g, b)
        end

        # Return original if unrecognized format
        color
      end

      # Check if two colors are equivalent
      def equivalent?(color1, color2)
        return false if color1.nil? || color2.nil?
        return true if color1 == color2

        norm1 = normalize(color1)
        norm2 = normalize(color2)

        return false if norm1.nil? || norm2.nil?

        norm1 == norm2
      end

      # Convert color to its canonical form (prefer named colors when available)
      def to_canonical(color)
        normalized = normalize(color)
        return color if normalized.nil?

        # Return special keywords as-is
        return normalized if SPECIAL_KEYWORDS.include?(normalized)

        # Convert hex to named color if available
        named = HEX_TO_NAMED[normalized]
        return named if named

        # Return normalized hex
        normalized
      end

      # Expand short hex colors: #fff → #ffffff
      def expand_short_hex(hex)
        return hex unless hex.match?(/^#[0-9a-f]{3}$/)

        chars = hex[1..3].chars
        "##{chars.map { |c| c * 2 }.join}"
      end

      # Convert RGB values to hex
      def rgb_to_hex(red, green, blue)
        # Clamp values to 0-255 range
        r = [[red.to_i, 0].max, 255].min
        g = [[green.to_i, 0].max, 255].min
        b = [[blue.to_i, 0].max, 255].min

        format("#%02x%02x%02x", r, g, b)
      end

      # Check if a color is valid according to SVG specifications
      def valid_css_color?(color)
        return false if color.nil? || color.empty?

        normalized = normalize(color)
        return false if normalized.nil?

        # Valid if it normalizes to something we recognize
        SPECIAL_KEYWORDS.include?(normalized) ||
          NAMED_COLORS.key?(color.strip.downcase) ||
          normalized.match?(/^#[0-9a-f]{6}$/)
      end

      # Get all equivalent forms of a color
      def equivalent_forms(color)
        normalized = normalize(color)
        return [color] if normalized.nil?

        forms = [normalized]

        # Add named form if available
        named = HEX_TO_NAMED[normalized]
        forms << named if named

        # Add short hex form if applicable
        if normalized.match?(/^#([0-9a-f])\1([0-9a-f])\2([0-9a-f])\3$/)
          short_hex = "##{$1}#{$2}#{$3}"
          forms << short_hex
        end

        # Add uppercase variants for hex
        if normalized.match?(/^#[0-9a-f]{6}$/)
          forms << normalized.upcase
        end

        forms.uniq
      end

      # Check if a color is in a list of allowed colors (with equivalence)
      def allowed_in_list?(color, allowed_colors)
        return false if color.nil? || allowed_colors.nil? || allowed_colors.empty?

        normalized = normalize(color)
        return false if normalized.nil?

        allowed_colors.any? { |allowed| equivalent?(color, allowed) }
      end

      # Calculate RGB sum for threshold-based validation
      def rgb_sum(color)
        return nil if color.nil? || color.empty?

        color = color.strip.downcase

        # Handle hex colors
        if color.match?(/^#[0-9a-f]{3}$/)
          # Expand short hex and calculate
          expanded = expand_short_hex(color)
          r = expanded[1..2].to_i(16)
          g = expanded[3..4].to_i(16)
          b = expanded[5..6].to_i(16)
          return r + g + b
        elsif color.match?(/^#[0-9a-f]{6}$/)
          r = color[1..2].to_i(16)
          g = color[3..4].to_i(16)
          b = color[5..6].to_i(16)
          return r + g + b
        end

        # Handle RGB functions with integers
        rgb_match = color.match(/^rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)$/)
        if rgb_match
          r, g, b = rgb_match[1..3].map(&:to_i)
          return r + g + b
        end

        # Handle RGB functions with percentages
        rgb_percent_match = color.match(/^rgb\s*\(\s*(\d+(?:\.\d+)?)%\s*,\s*(\d+(?:\.\d+)?)%\s*,\s*(\d+(?:\.\d+)?)%\s*\)$/)
        if rgb_percent_match
          r = (rgb_percent_match[1].to_f * 255 / 100).round
          g = (rgb_percent_match[2].to_f * 255 / 100).round
          b = (rgb_percent_match[3].to_f * 255 / 100).round
          return r + g + b
        end

        # Handle mixed RGB functions
        rgb_mixed_match = color.match(/^rgb\s*\(\s*(\d+(?:\.\d+)?%?)\s*,\s*(\d+(?:\.\d+)?%?)\s*,\s*(\d+(?:\.\d+)?%?)\s*\)$/)
        if rgb_mixed_match
          r = parse_rgb_value(rgb_mixed_match[1])
          g = parse_rgb_value(rgb_mixed_match[2])
          b = parse_rgb_value(rgb_mixed_match[3])
          return r + g + b
        end

        # Handle named colors
        if NAMED_COLORS.key?(color)
          hex = NAMED_COLORS[color]
          r = hex[1..2].to_i(16)
          g = hex[3..4].to_i(16)
          b = hex[5..6].to_i(16)
          return r + g + b
        end

        nil
      end

      private

      # Parse individual RGB value (percentage or absolute)
      def parse_rgb_value(value_str)
        value_str = value_str.strip
        if value_str.end_with?("%")
          # Percentage value
          percent = value_str.chomp("%").to_f
          (percent * 255 / 100).round
        else
          # Absolute value
          value_str.to_i
        end
      end
    end
  end
end
