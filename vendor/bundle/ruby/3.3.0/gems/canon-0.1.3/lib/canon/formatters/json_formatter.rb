# frozen_string_literal: true

require "json"

module Canon
  module Formatters
    # JSON formatter for canonicalization
    class JsonFormatter
      def self.format(json)
        parsed = parse(json)
        JSON.pretty_generate(sort_json_keys(parsed))
      end

      def self.parse(json)
        JSON.parse(json)
      end

      def self.sort_json_keys(obj)
        case obj
        when Hash
          obj.transform_values { |v| sort_json_keys(v) }
            .sort.to_h
        when Array
          obj.map { |item| sort_json_keys(item) }
        else
          obj
        end
      end
    end
  end
end
