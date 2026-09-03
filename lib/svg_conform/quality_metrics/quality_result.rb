# frozen_string_literal: true

require "lutaml/model"

module SvgConform
  module QualityMetrics
    # Immutable value object representing complete quality analysis result.
    #
    # Combines all quality dimensions into a single value object.
    #
    # @example
    #   result = QualityResult.new(
    #     file_path: "image.svg",
    #     file_size_kb: 24.5,
    #     quality_score: QualityScore.new(value: 85, level: :good),
    #     error_breakdown: ErrorBreakdown.new(total: 3, ...),
    #     complexity: ComplexityMetrics.new(...),
    #     features: FeatureFlags.new(...),
    #     content_health: :good,
    #     size_category: :small
    #   )
    #
    #   result.clean?                # => false
    #   result.fixable?              # => true
    #   result.to_report.render      # => Terminal colored output
    #
    class QualityResult < Lutaml::Model::Serializable
      attribute :file_path, :string
      attribute :file_size_kb, :float
      attribute :quality_score, QualityScore
      attribute :error_breakdown, ErrorBreakdown
      attribute :complexity, ComplexityMetrics
      attribute :features, FeatureFlags
      attribute :content_health, :symbol
      attribute :size_category, :symbol

      def initialize(**args)
        super(args)
        freeze
      end

      # Value equality
      def ==(other)
        other.is_a?(QualityResult) &&
          file_path == other.file_path &&
          file_size_kb == other.file_size_kb &&
          quality_score == other.quality_score &&
          error_breakdown == other.error_breakdown &&
          complexity == other.complexity &&
          features == other.features &&
          content_health == other.content_health &&
          size_category == other.size_category
      end
      alias eql? ==

      def hash
        [file_path, file_size_kb, quality_score, error_breakdown,
         complexity, features, content_health, size_category].hash
      end

      # @return [Boolean] true if file has no errors
      def clean?
        error_breakdown.clean?
      end

      # @return [Boolean] true if errors can be automatically fixed
      def fixable?
        error_breakdown.remediable.positive? && !error_breakdown.has_non_remediable?
      end

      # @return [Boolean] true if file requires manual intervention
      def requires_manual_fix?
        error_breakdown.has_non_remediable?
      end

      # Convert to SvgQualityReport for backward compatibility
      # @return [SvgConform::SvgQualityReport]
      def to_report
        SvgQualityReport.new(
          file_path: file_path,
          quality_score: quality_score.value,
          quality_level: quality_score.level,
          error_count: error_breakdown.total,
          remediable_errors: error_breakdown.remediable,
          non_remediable_errors: error_breakdown.non_remediable,
          critical_errors: error_breakdown.critical,
          high_errors: error_breakdown.high,
          medium_errors: error_breakdown.medium,
          low_errors: error_breakdown.low,
          element_count: complexity.element_count,
          file_size_kb: file_size_kb,
          complexity_index: complexity.index,
          content_health: content_health,
          size_category: size_category,
          has_base64: features.has_base64,
          has_foreign_ns: features.has_foreign_ns,
          has_masks: features.has_masks,
          has_clip_paths: features.has_clip_paths,
          has_external_refs: features.has_external_refs,
        )
      end
    end
  end
end
