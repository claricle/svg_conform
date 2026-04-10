# frozen_string_literal: true

module SvgConform
  module QualityMetrics
    # Calculates quality score (0-100) and determines quality level.
    #
    # @example
    #   config = Configuration.default
    #   calculator = QualityCalculator.new(config)
    #
    #   score = calculator.calculate(validation_result, error_breakdown, 10240)
    #   puts score.value   # => 85
    #   puts score.level    # => :good
    #   puts score.good?    # => true
    #
    class QualityCalculator
      # @param config [Configuration]
      def initialize(config)
        @config = config
      end

      # Calculate quality score
      #
      # @param _validation_result [SvgConform::ValidationResult] (reserved for future use)
      # @param error_breakdown [ErrorBreakdown]
      # @param file_size_bytes [Integer]
      # @return [QualityScore]
      def calculate(_validation_result, error_breakdown, file_size_bytes)
        formula = @config.quality_formula
        base_score = 100.0

        if error_breakdown.clean?
          return QualityScore.new(
            value: (base_score + formula.valid_structure_bonus).clamp(0, 100).to_i,
            level: :excellent,
          )
        end

        # 1. Penalize error density (errors per KB)
        file_size_kb = file_size_bytes.to_f / 1024.0
        error_density = error_breakdown.total.to_f / [file_size_kb, 0.1].max
        density_penalty = (error_density * formula.error_density_weight).clamp(
          0,
          formula.error_density_max_penalty,
        )
        base_score -= density_penalty

        # 2. Penalize non-remediable errors
        non_remediable_penalty = (error_breakdown.non_remediable * formula.non_remediable_weight).clamp(
          0,
          formula.non_remediable_max_penalty,
        )
        base_score -= non_remediable_penalty

        # 3. Penalize critical errors
        critical_penalty = (error_breakdown.critical * formula.critical_weight).clamp(
          0,
          formula.critical_max_penalty,
        )
        base_score -= critical_penalty

        # 4. Penalize high-severity errors
        high_penalty = (error_breakdown.high * formula.high_weight).clamp(
          0,
          formula.high_max_penalty,
        )
        base_score -= high_penalty

        score_value = base_score.clamp(0, 100).to_i
        score_level = @config.quality_level_for(score_value)

        QualityScore.new(value: score_value, level: score_level)
      end

      # Calculate all quality metrics at once
      #
      # @param validation_result [SvgConform::ValidationResult]
      # @param file_path [String]
      # @param file_size_bytes [Integer]
      # @param error_breakdown [ErrorBreakdown]
      # @param complexity_metrics [ComplexityMetrics]
      # @param feature_flags [FeatureFlags]
      # @return [QualityResult]
      def calculate_all(validation_result:, file_path:, file_size_bytes:,
                       error_breakdown:, complexity_metrics:, feature_flags:)
        quality_score = calculate(validation_result, error_breakdown, file_size_bytes)
        file_size_kb = file_size_bytes.to_f / 1024.0

        QualityResult.new(
          file_path: file_path,
          file_size_kb: file_size_kb.round(2),
          quality_score: quality_score,
          error_breakdown: error_breakdown,
          complexity: complexity_metrics,
          features: feature_flags,
          content_health: determine_content_health(error_breakdown),
          size_category: @config.size_category_for(file_size_kb),
        )
      end

      private

      def determine_content_health(error_breakdown)
        return :good if error_breakdown.clean?

        if @config.content_health.severe_issues_any_critical && error_breakdown.has_critical?
          return :severe_issues
        end

        if error_breakdown.total >= @config.content_health.severe_issues_min_errors
          return :severe_issues
        end

        if @config.content_health.moderate_issues_any_high && error_breakdown.high.positive?
          return :moderate_issues
        end

        if error_breakdown.total >= @config.content_health.moderate_issues_max_errors
          return :moderate_issues
        end

        if error_breakdown.total <= @config.content_health.minor_issues_max_errors
          return :minor_issues
        end

        :moderate_issues
      end
    end
  end
end
