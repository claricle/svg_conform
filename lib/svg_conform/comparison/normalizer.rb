# frozen_string_literal: true

module SvgConform
  module Comparison
    # Shared normalization utilities for semantic comparison
    #
    # This module provides centralized normalization logic for:
    # - Color values (hex, rgb, named colors)
    # - Namespace URIs
    # - Attribute and style values
    #
    # Normalization ensures semantic equivalence by converting different
    # representations of the same value into a canonical form.
    module Normalizer
      # Color value normalization maps
      COLOR_MAP = {
        "white" => %w[white #fff #ffffff rgb(255,255,255) rgb(255 255 255)
                      rgb(100%,100%,100%) rgb(100% 100% 100%)],
        "black" => %w[black #000 #000000 rgb(0,0,0) rgb(0 0 0) rgb(0%,0%,0%)
                      rgb(0% 0% 0%)],
        "red" => %w[red #f00 #ff0000 rgb(255,0,0) rgb(255 0 0)
                    rgb(100%,0%,0%) rgb(100% 0% 0%)],
        "green" => %w[green #0f0 #00ff00 rgb(0,255,0) rgb(0 255 0)
                      rgb(0%,100%,0%) rgb(0% 100% 0%)],
        "blue" => %w[blue #00f #0000ff rgb(0,0,255) rgb(0 0 255)
                     rgb(0%,0%,100%) rgb(0% 0% 100%)],
        "grey" => %w[grey gray],
      }.freeze

      # Namespace normalization patterns
      NAMESPACE_PATTERNS = {
        "inkscape" => /inkscape/i,
        "sodipodi" => /sodipodi/i,
        "svg" => /w3\.org.*svg/i,
      }.freeze

      class << self
        # Normalize color values to handle different formats
        #
        # Converts various color representations (named, hex, rgb) into
        # a canonical form for semantic comparison.
        #
        # @param color [String] the color value to normalize
        # @return [String] the normalized color value
        def normalize_color_value(color)
          # Normalize color values to handle different formats
          normalized = color.downcase.strip

          # Check against color map (reverse lookup)
          COLOR_MAP.each do |canonical, variants|
            return canonical if variants.include?(normalized)
          end

          # For hex colors, normalize to lowercase without spaces
          if /\A#[0-9a-f]{3,8}\z/i.match?(normalized)
            normalized.downcase
          elsif /\Argb\s*\(/i.match?(normalized)
            # Normalize RGB format by removing spaces
            normalized.gsub(/\s+/, "")
          else
            normalized
          end
        end

        # Normalize namespace URIs to canonical form
        #
        # Converts various namespace URI representations into a canonical
        # form for semantic comparison.
        #
        # @param namespace [String] the namespace URI to normalize
        # @return [String] the normalized namespace
        def normalize_namespace(namespace)
          NAMESPACE_PATTERNS.each do |canonical, pattern|
            return canonical if namespace.match?(pattern)
          end

          namespace
        end

        # Normalize common values for semantic comparison
        #
        # Handles array-like values from svgcheck and applies standard
        # normalization (lowercase, strip).
        #
        # @param value [String] the value to normalize
        # @return [String] the normalized value
        def normalize_value(value)
          # Normalize common values for semantic comparison
          normalized = value.downcase.strip

          # Handle array-like values from svgcheck (e.g., "['malformed']" -> "malformed")
          normalized = ::Regexp.last_match(1) if normalized =~ /\A\['([^']{1,200})'\]\z/

          normalized
        end

        # Normalize message text for semantic comparison
        #
        # Extracts key semantic components from message text by removing
        # punctuation and normalizing case.
        #
        # @param message [String] the message to normalize
        # @return [String] the normalized message
        def normalize_message(message)
          # Extract key semantic components from message
          message.downcase.gsub(/['":]/, "").strip
        end

        # Normalize attribute values for comparison
        #
        # @param value [String] the attribute value to normalize
        # @return [String] the normalized value
        def normalize_attribute_value(value)
          # Normalize attribute values for comparison
          value.strip.downcase
        end

        # Normalize style values for comparison
        #
        # @param value [String] the style value to normalize
        # @return [String] the normalized value
        def normalize_style_value(value)
          # Normalize style values for comparison
          value.strip.downcase
        end

        # Check if a value is a color attribute
        #
        # @param attribute [String] the attribute name
        # @return [Boolean] true if the attribute is a color attribute
        def color_attribute?(attribute)
          %w[fill stroke].include?(attribute)
        end
      end
    end
  end
end
