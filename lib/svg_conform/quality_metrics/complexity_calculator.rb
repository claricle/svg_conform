# frozen_string_literal: true

module SvgConform
  module QualityMetrics
    # Calculates complexity index (1-10) for SVG documents.
    #
    # @example
    #   config = Configuration.default
    #   calculator = ComplexityCalculator.new(config)
    #
    #   metrics = calculator.calculate(element_count: 150, features: FeatureFlags.new(...))
    #   puts metrics.index  # => 6.5
    #   puts metrics.complexity_level  # => :complex
    #
    class ComplexityCalculator
      # @param config [Configuration]
      def initialize(config)
        @config = config
      end

      # Calculate complexity metrics
      #
      # @param element_count [Integer] Number of elements in the document
      # @param features [FeatureFlags] Detected features
      # @param max_depth [Integer, nil] Maximum nesting depth (optional, calculated if nil)
      # @return [ComplexityMetrics]
      def calculate(element_count:, features:, max_depth: nil)
        element_score = Math.log10([element_count, 1].max) * @config.complexity.base_element_multiplier
        depth_score = (max_depth || 0) * @config.complexity.depth_weight
        feature_bonus = calculate_feature_bonus(features)

        complexity = element_score + depth_score + feature_bonus
        max_index = @config.complexity.max_index

        ComplexityMetrics.new(
          index: [complexity.clamp(1.0, max_index), 1.0].max,
          element_count: element_count,
          max_depth: max_depth || 0,
        )
      end

      # Calculate complexity from raw content
      #
      # @param content [String] SVG file content
      # @param features [FeatureFlags] Detected features
      # @return [ComplexityMetrics]
      def calculate_from_content(content:, features:)
        element_count = count_elements(content)
        max_depth = calculate_max_depth(content)

        calculate(element_count: element_count, features: features, max_depth: max_depth)
      end

      private

      def count_elements(content)
        # Match opening tags: <tagname or </tagname but not <? or <! or />
        content.scan(/<[?!]?[\w-]+[\s>]/).size
      end

      def calculate_max_depth(content)
        # Simple regex-based depth estimation
        # Track opening and closing tags to estimate nesting
        depth = 0
        max_depth = 0
        in_tag = false

        content.each_char do |char|
          case char
          when "<"
            in_tag = true
            # Check if it's a closing tag
            if content[content.index(char) + 1] == "/"
              depth -= 1
            else
              depth += 1
              max_depth = [max_depth, depth].max
            end
          when ">"
            in_tag = false
          end
        end

        max_depth
      end

      def calculate_feature_bonus(features)
        bonus = 0.0
        bonus += features.has_masks ? @config.complexity.feature_bonus(:has_masks) : 0
        bonus += features.has_clip_paths ? @config.complexity.feature_bonus(:has_clip_paths) : 0
        bonus += features.has_base64 ? @config.complexity.feature_bonus(:has_base64) : 0
        bonus += features.has_foreign_ns ? @config.complexity.feature_bonus(:has_foreign_ns) : 0
        bonus += features.has_external_refs ? @config.complexity.feature_bonus(:has_external_refs) : 0
        bonus
      end
    end
  end
end
