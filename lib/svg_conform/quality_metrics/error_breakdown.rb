# frozen_string_literal: true

require "lutaml/model"

module SvgConform
  module QualityMetrics
    # Immutable value object representing error breakdown by severity and remediability.
    #
    # @example
    #   breakdown = ErrorBreakdown.new(
    #     total: 15,
    #     critical: 1,
    #     high: 3,
    #     medium: 8,
    #     low: 3,
    #     remediable: 12,
    #     non_remediable: 3
    #   )
    #
    #   breakdown.clean?              # => false
    #   breakdown.worst_severity     # => :critical
    #
    class ErrorBreakdown < Lutaml::Model::Serializable
      attribute :total, :integer, default: 0
      attribute :critical, :integer, default: 0
      attribute :high, :integer, default: 0
      attribute :medium, :integer, default: 0
      attribute :low, :integer, default: 0
      attribute :remediable, :integer, default: 0
      attribute :non_remediable, :integer, default: 0

      # Ensure immutability after initialization
      after_initialize { freeze }

      # Value equality
      def ==(other)
        other.is_a?(ErrorBreakdown) &&
          total == other.total &&
          critical == other.critical &&
          high == other.high &&
          medium == other.medium &&
          low == other.low &&
          remediable == other.remediable &&
          non_remediable == other.non_remediable
      end
      alias eql? ==

      def hash
        [total, critical, high, medium, low, remediable, non_remediable].hash
      end

      # @return [Boolean] true if there are no errors
      def clean?
        total.zero?
      end

      # @return [Boolean] true if any critical errors exist
      def has_critical?
        critical.positive?
      end

      # @return [Boolean] true if any non-remediable errors exist
      def has_non_remediable?
        non_remediable.positive?
      end

      # @return [Symbol] Worst severity level present
      def worst_severity
        return :none if clean?

        return :critical if critical.positive?
        return :high if high.positive?
        return :medium if medium.positive?
        return :low if low.positive?

        :none
      end
    end
  end
end
