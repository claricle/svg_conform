# frozen_string_literal: true

require "csv"

module SvgConform
  module QualityMetrics
    # Formats quality results into various output formats.
    #
    # @example CSV output
    #   formatter = QualityReportFormatter.new
    #   csv = formatter.format_csv(results)
    #
    # @example JSON output
    #   json = formatter.format_json(results)
    #
    class QualityReportFormatter
      CSV_HEADERS = %w[
        file_path quality_score quality_level error_count
        remediable_errors non_remediable_errors
        critical_errors high_errors medium_errors low_errors
        element_count file_size_kb complexity_index
        content_health size_category
        has_base64 has_foreign_ns has_masks has_clip_paths has_external_refs
      ].freeze

      # Format results as CSV
      # @param results [Array<SvgQualityReport>]
      # @return [String]
      def format_csv(results)
        return "" if results.empty?

        CSV.generate do |csv|
          csv << CSV_HEADERS

          results.each do |result|
            csv << CSV_HEADERS.map { |h| format_csv_value(result, h) }
          end
        end
      end

      # Format results as JSON
      # @param results [Array<SvgQualityReport>]
      # @return [String]
      def format_json(results)
        require "json"

        results.map(&:to_h).to_json
      end

      private

      def format_csv_value(result, header)
        value = result.public_send(header.to_sym)

        case value
        when nil then ""
        when true then "true"
        when false then "false"
        else
          str = value.to_s
          if str.include?(",") || str.include?('"') || str.include?("\n")
            "\"#{str.gsub('"', '""')}\""
          else
            str
          end
        end
      end
    end
  end
end
