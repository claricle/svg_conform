# frozen_string_literal: true

module Moxml
  module XmlUtils
    class Encoder
      attr_reader :mode

      MAPPINGS = {
        none: {},
        basic: {
          "<" => "&lt;",
          ">" => "&gt;",
          "&" => "&amp;"
        },
        quotes: {
          "'" => "&apos;",
          '"' => "&quot;"
        },
        full: {
          "<" => "&lt;",
          ">" => "&gt;",
          "'" => "&apos;",
          '"' => "&quot;",
          "&" => "&amp;"
        }
      }.freeze
      MODES = MAPPINGS.keys.freeze

      def initialize(text, mode = nil)
        @text = text
        @mode = valid_mode(mode)
      end

      def call
        return @text if mode == :none

        @text.to_s.gsub(/[#{mapping.keys.join}]/) do |match|
          mapping[match]
        end
      end

      protected

      def valid_mode(raw_mode)
        mode_sym = raw_mode.to_s.to_sym

        MODES.include?(mode_sym) ? mode_sym : MODES.first
      end

      def mapping
        MAPPINGS[mode] || {}
      end
    end
  end
end
