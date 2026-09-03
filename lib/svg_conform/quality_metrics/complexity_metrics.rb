# frozen_string_literal: true

require "lutaml/model"

module SvgConform
  module QualityMetrics
    # Immutable value object representing SVG complexity metrics.
    #
    # @example
    #   complexity = ComplexityMetrics.new(
    #     index: 6.5,
    #     element_count: 150,
    #     max_depth: 12
    #   )
    #
    #   complexity.complexity_level  # => :complex
    #   complexity.high?             # => false
    #
    class ComplexityMetrics < Lutaml::Model::Serializable
      attribute :index, :float, default: 1.0
      attribute :element_count, :integer, default: 0
      attribute :max_depth, :integer, default: 0

      def initialize(**args)
        super(args)
        freeze
      end

      # Value equality
      def ==(other)
        other.is_a?(ComplexityMetrics) &&
          index == other.index &&
          element_count == other.element_count &&
          max_depth == other.max_depth
      end
      alias eql? ==

      def hash
        [index, element_count, max_depth].hash
      end

      # Complexity level descriptions
      def complexity_level
        case index
        when 1.0..2.9 then :simple
        when 3.0..4.9 then :moderate
        when 5.0..6.9 then :complex
        when 7.0..8.9 then :very_complex
        else :extremely_complex
        end
      end

      # @return [Boolean] true if complexity is high (7+)
      def high?
        index >= 7.0
      end
    end
  end
end
