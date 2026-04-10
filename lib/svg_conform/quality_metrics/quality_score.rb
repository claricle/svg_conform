# frozen_string_literal: true

require "lutaml/model"

module SvgConform
  module QualityMetrics
    # Immutable value object representing a quality score and its classification.
    #
    # @example
    #   score = QualityScore.new(value: 85, level: :good)
    #   score.good?                  # => true
    #   score.acceptable?            # => true
    #   score.grade                  # => "B"
    #
    class QualityScore < Lutaml::Model::Serializable
      attribute :value, :integer, default: 0
      attribute :level, :symbol, default: :critical

      LEVELS = %i[excellent good fair poor critical].freeze

      after_initialize { freeze }

      # Value equality
      def ==(other)
        other.is_a?(QualityScore) &&
          value == other.value &&
          level == other.level
      end
      alias eql? ==

      def hash
        [value, level].hash
      end

      # Quality level predicates
      LEVELS.each do |lvl|
        define_method("#{lvl}?") { level == lvl }
      end

      # @return [Boolean] true if score indicates good quality
      def acceptable?
        excellent? || good?
      end

      # @return [Boolean] true if score indicates problems
      def problematic?
        fair? || poor? || critical?
      end

      # @return [String] Letter grade equivalent
      def grade
        case level
        when :excellent then "A"
        when :good then "B"
        when :fair then "C"
        when :poor then "D"
        when :critical then "F"
        else "?"
        end
      end

      LEVEL_NEXT = {
        critical: :poor,
        poor: :fair,
        fair: :good,
        good: :excellent,
        excellent: :excellent,
      }.freeze

      # @return [Symbol] Next better level, or self if already excellent
      def next_level
        LEVEL_NEXT[level] || :excellent
      end
    end
  end
end
