# frozen_string_literal: true

require_relative "base_requirement"

module SvgConform
  module Requirements
    # Detects SVG files where text is rendered as outlined path glyphs
    # instead of native <text> elements.
    #
    # An SVG is flagged when ALL of these conditions are met:
    #   1. No <text> element present
    #   2. No <image> element present
    #   3. Contains bezier curves (C/c/Q/q commands) in path d attributes
    #   4. Longest single path d string >= min_d_length
    #
    # These files are problematic because:
    #   - Text cannot be indexed or copied
    #   - Glyph outlines are much larger than text elements
    #   - Poorly rendered in many graphics viewers
    #
    # This is a quality check (severity: warning), not a schema violation.
    # There is no remediation since outlined text cannot be auto-converted.
    class TextAsPathRequirement < BaseRequirement
      attribute :type, :string, default: -> { "TextAsPathRequirement" }
      attribute :min_d_length, :integer, default: 500
      attribute :min_bezier, :integer, default: 5

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "type", to: :type
        map "min_d_length", to: :min_d_length
        map "min_bezier", to: :min_bezier
      end

      # State class for tracking elements and paths during SAX parsing
      class State
        attr_accessor :has_text_element, :has_image_element, :path_ds

        def initialize
          @has_text_element = false
          @has_image_element = false
          @path_ds = []
        end
      end

      def needs_deferred_validation?
        true
      end

      # Override validate_document to do nothing since this requirement
      # only supports SAX-based deferred validation.
      # DOM validation is not supported because we need to collect all
      # path data before making a determination.
      def validate_document(document, context)
        # No-op: This requirement only works with SAX deferred validation
      end

      def collect_sax_data(element, context)
        state = context.state_for(self)

        case element.name
        when "text"
          state.has_text_element = true
        when "image"
          state.has_image_element = true
        when "path"
          d_value = element["d"]
          state.path_ds << d_value if d_value && !d_value.empty?
        end
      end

      def validate_sax_complete(context)
        state = context.state_for(self)

        # Skip if has text or image elements (not text-as-path)
        return if state.has_text_element || state.has_image_element
        return if state.path_ds.empty?

        # Calculate metrics
        longest_d = state.path_ds.map(&:length).max
        total_bezier = state.path_ds.sum { |d| d.scan(/[CQcq]/).count }

        # Check if this is a text-as-path SVG
        if longest_d >= min_d_length && total_bezier >= min_bezier
          context.add_error(
            requirement_id: id,
            message: "Text appears to be rendered as paths (d-length: #{longest_d}, " \
                     "beziers: #{total_bezier}). Consider using <text> elements " \
                     "for better accessibility and smaller file size.",
            node: nil,
            severity: :warning,
          )
        end
      end
    end
  end
end
