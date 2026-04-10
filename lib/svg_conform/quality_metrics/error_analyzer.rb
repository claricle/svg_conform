# frozen_string_literal: true

module SvgConform
  module QualityMetrics
    # Analyzes validation errors and produces a structured ErrorBreakdown.
    #
    # @example
    #   config = Configuration.default
    #   analyzer = ErrorAnalyzer.new(config)
    #
    #   breakdown = analyzer.analyze(validation_result)
    #   puts breakdown.total              # => 15
    #   puts breakdown.critical           # => 1
    #   puts breakdown.has_non_remediable? # => true
    #
    class ErrorAnalyzer
      # @param config [Configuration]
      def initialize(config)
        @config = config
      end

      # Analyze validation result and produce an ErrorBreakdown
      #
      # @param validation_result [SvgConform::ValidationResult]
      # @return [ErrorBreakdown] Structured error analysis
      def analyze(validation_result)
        errors = validation_result.errors || []

        ErrorBreakdown.new(
          total: errors.size,
          critical: count_by_severity(errors, :critical),
          high: count_by_severity(errors, :high),
          medium: count_by_severity(errors, :medium),
          low: count_by_severity(errors, :low),
          remediable: count_remediable(errors),
          non_remediable: count_non_remediable(errors),
        )
      end

      # Determine content health from breakdown
      #
      # @param breakdown [ErrorBreakdown]
      # @return [Symbol] :good, :minor_issues, :moderate_issues, or :severe_issues
      def determine_health(breakdown)
        return :good if breakdown.clean?

        # Check for severe issues
        if @config.content_health.severe_issues_any_critical && breakdown.has_critical?
          return :severe_issues
        end

        if breakdown.total >= @config.content_health.severe_issues_min_errors
          return :severe_issues
        end

        # Check for moderate issues
        if @config.content_health.moderate_issues_any_high && breakdown.high.positive?
          return :moderate_issues
        end

        if breakdown.total >= @config.content_health.moderate_issues_max_errors
          return :moderate_issues
        end

        # Check for minor issues
        if breakdown.total <= @config.content_health.minor_issues_max_errors
          return :minor_issues
        end

        :moderate_issues
      end

      private

      def count_by_severity(errors, severity)
        errors.count do |error|
          @config.severity_for(error.violation_type) == severity
        end
      end

      def count_remediable(errors)
        errors.count { |e| @config.remediable?(e.violation_type) }
      end

      def count_non_remediable(errors)
        errors.count { |e| @config.non_remediable?(e.violation_type) }
      end
    end
  end
end
