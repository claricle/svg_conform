# frozen_string_literal: true

require_relative "base_reference"

module SvgConform
  module References
    # Classifies reference values into appropriate reference types
    class ReferenceClassifier
      # Classify a reference value into its appropriate type
      def self.classify(href_value, element_name:, attribute_name:,
                       line_number: nil, column_number: nil)
        return nil if href_value.nil? || href_value.empty?

        reference_class = determine_type(href_value)
        reference_class.new(
          value: href_value,
          element_name: element_name,
          attribute_name: attribute_name,
          line_number: line_number,
          column_number: column_number,
        )
      end

      def self.determine_type(href)
        case href
        when /^#/
          InternalFragmentReference
        when /^data:/i
          DataUriReference
        when /^urn:/i
          UrnReference
        when %r{^https?://}i
          ExternalUrlReference
        when %r{^[./]}
          # Relative paths starting with ./ or /
          RelativePathReference
        else
          # Could be relative or external depending on context
          # Treat as relative by default (conservative approach)
          RelativePathReference
        end
      end
    end
  end
end
