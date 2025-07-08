# frozen_string_literal: true

module SvgConform
  module Compatibility
    # Value object representing the results of a compatibility comparison
    class ComparisonResult
      attr_reader :filename, :type, :validation_comparison, :content_comparison,
                  :xml_equivalence, :svg_conform_result, :svgcheck_result

      def initialize(filename:, type:, **options)
        @filename = filename
        @type = type
        @validation_comparison = options[:validation_comparison]
        @content_comparison = options[:content_comparison]
        @xml_equivalence = options[:xml_equivalence]
        @svg_conform_result = options[:svg_conform_result]
        @svgcheck_result = options[:svgcheck_result]
      end

      def semantic_validation?
        @type == :semantic_validation
      end

      def semantic_repair?
        @type == :semantic_repair
      end

      def basic_validation?
        @type == :basic_validation
      end

      def basic_repair?
        @type == :basic_repair
      end

      def compatibility_score
        return 0.0 unless @validation_comparison

        raw_score = @validation_comparison[:compatibility_score] || 0.0
        raw_score * 100.0
      end

      def validity_match?
        return false unless @validation_comparison

        @validation_comparison.dig(:overall_validity, :match) || false
      end

      def svg_conform_valid?
        if semantic_validation? || semantic_repair?
          @validation_comparison&.dig(:overall_validity, :svg_conform) || false
        else
          @svg_conform_result&.success? || false
        end
      end

      def svgcheck_valid?
        if semantic_validation? || semantic_repair?
          @validation_comparison&.dig(:overall_validity, :svgcheck) || false
        else
          @svgcheck_result&.valid || false
        end
      end

      def content_equivalence_score
        return 0.0 unless @content_comparison

        raw_score = @content_comparison[:semantic_equivalence] || 0.0
        raw_score * 100.0
      end

      def xml_equivalent?
        return false unless @xml_equivalence

        @xml_equivalence[:xml_equivalent] || false
      end

      def xml_differences
        return [] unless @xml_equivalence

        @xml_equivalence[:differences] || []
      end

      def xml_error
        return nil unless @xml_equivalence

        @xml_equivalence[:error]
      end

      def successful_remediation?
        if semantic_repair?
          svg_conform_valid?
        elsif basic_repair?
          @svg_conform_result&.success? || false
        else
          false
        end
      end

      def issues_fixed
        return 0 unless basic_repair?

        @svg_conform_result&.issues_fixed || 0
      end

      def remediations_applied
        return 0 unless basic_repair?

        @svg_conform_result&.remediations_applied || 0
      end

      def error_count
        if semantic_validation? || semantic_repair?
          # For semantic results, we'd need to extract from validation_comparison
          0
        else
          # For basic repair mode, count initial validation errors
          svg_conform_errors = if @svg_conform_result&.initial_validation
                                 @svg_conform_result.initial_validation.failed_requirements.length
                               else
                                 0
                               end

          svgcheck_errors = @svgcheck_result&.errors&.total_count || 0

          svg_conform_errors + svgcheck_errors
        end
      end

      def to_h
        {
          filename: @filename,
          type: @type,
          compatibility_score: compatibility_score,
          validity_match: validity_match?,
          svg_conform_valid: svg_conform_valid?,
          svgcheck_valid: svgcheck_valid?,
          content_equivalence_score: content_equivalence_score,
          xml_equivalent: xml_equivalent?,
          successful_remediation: successful_remediation?,
          issues_fixed: issues_fixed,
          remediations_applied: remediations_applied
        }
      end
    end
  end
end
