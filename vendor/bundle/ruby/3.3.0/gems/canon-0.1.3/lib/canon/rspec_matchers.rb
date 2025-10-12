# frozen_string_literal: true

require "canon" unless defined?(::Canon)
require "compare-xml"
require "diffy"

begin
  require "rspec/expectations"
rescue LoadError
end

module Canon
  module RSpecMatchers
    # Base matcher class for serialization equivalence
    class SerializationMatcher
      def initialize(expected, format = :xml)
        @expected = expected
        unless SUPPORTED_FORMATS.include?(format.to_sym)
          raise Canon::Error, "Unsupported format: #{format}"
        end

        @format = format.to_sym
        @result = nil
      end

      def matches?(target)
        @target = target
        send("match_#{@format}")
      rescue NoMethodError
        raise Canon::Error, "Unsupported format: #{@format}"
      end

      def match_xml
        @result = CompareXML.equivalent?(
          Nokogiri::XML(@target),
          Nokogiri::XML(@expected),
          {
            collapse_whitespace: true,
            ignore_attr_order: true,
            verbose: true,
          },
        )

        @result.empty?
      end

      # Canonicalize and check string equivalence for YAML/JSON
      def match_yaml
        canonicalize_and_compare(:yaml)
      end

      def match_json
        canonicalize_and_compare(:json)
      end

      private

      def canonicalize_and_compare(format)
        @actual_sorted = Canon.format(@target, format)
        @expected_sorted = Canon.format(@expected, format)
        @actual_sorted == @expected_sorted
      end

      def failure_message
        case @format
        when :xml
          xml_failure_message
        when :yaml, :json
          generic_failure_message
        end
      end

      def xml_failure_message
        index = 0
        @result.map do |hash|
          index += 1
          index_str = index.to_s.rjust(2, "0")
          "DIFF #{index_str}:\n" \
          "    expected node: #{hash[:node1]}\n" \
          "    actual node  : #{hash[:node2]}\n" \
          "    diff from    : #{hash[:diff1]}\n" \
          "    diff to      : #{hash[:diff2]}\n"
        end.join("\n")
      end

      def generic_failure_message
        diff = Diffy::Diff.new(
          @expected_sorted,
          @actual_sorted,
          include_diff_info: false,
          include_plus_and_minus_in_html: true,
          diff_options: "-u",
        )

        "expected #{@format.to_s.upcase} to be equivalent\n\n" \
          "Diff:\n" +
          diff.to_s(:color)
      end

      def failure_message_when_negated
        [
          "expected:",
          @target.to_s,
          "not be equivalent to:",
          @expected.to_s,
        ].join("\n")
      end

      def diffable
        true
      end
    end

    # Matcher methods
    def be_serialization_equivalent_to(expected, format: :xml)
      SerializationMatcher.new(expected, format)
    end

    def be_analogous_with(expected)
      SerializationMatcher.new(expected, :xml)
    end

    def be_xml_equivalent_to(expected)
      SerializationMatcher.new(expected, :xml)
    end

    def be_yaml_equivalent_to(expected)
      SerializationMatcher.new(expected, :yaml)
    end

    def be_json_equivalent_to(expected)
      SerializationMatcher.new(expected, :json)
    end

    if defined?(::RSpec)
      RSpec.configure do |config|
        config.include(Canon::RSpecMatchers)
      end
    end
  end
end
