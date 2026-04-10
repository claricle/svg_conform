# frozen_string_literal: true

require "lutaml/model"

module SvgConform
  module QualityMetrics
    # Immutable, type-safe configuration for SVG quality metrics.
    #
    # Loads from YAML and provides typed access to all configuration values.
    # Configuration is completely encapsulated - no raw hash exposure.
    #
    # @example
    #   config = Configuration.default
    #
    #   # Access typed values
    #   config.severity_weight(:critical)  # => 5
    #   config.quality_level_for(85)       # => :good
    #
    # @example Custom configuration
    #   custom = Configuration.from_hash({
    #     "severity_levels" => {"critical" => {"default_weight" => 10}}
    #   })
    #   merged = config.merge(custom)
    #
    class Configuration
      DEFAULT_CONFIG_PATH = File.join(__dir__,
                                      "../../../config/quality_metrics.yml").freeze

      class << self
        # @return [Configuration] Default configuration from bundled YAML
        def default
          from_yaml(DEFAULT_CONFIG_PATH)
        end

        # @param path [String] Path to YAML file
        # @return [Configuration]
        def from_yaml(path)
          unless File.exist?(path)
            raise ArgumentError, "Configuration file not found: #{path}"
          end

          hash = YAML.safe_load_file(path, permitted_classes: [Symbol],
                                           permitted_symbols: [], aliases: true)
          new(hash)
        end

        # @param hash [Hash] Configuration hash
        # @return [Configuration]
        def from_hash(hash)
          new(hash)
        end
      end

      def initialize(hash)
        @hash = hash.freeze
        freeze
      end

      # @param other [Configuration]
      # @return [Configuration] Merged configuration
      def merge(other)
        merged = deep_merge(@hash, other.instance_variable_get(:@hash))
        Configuration.from_hash(merged)
      end

      # =========================================================================
      # Severity Configuration
      # =========================================================================

      # @return [Hash<Symbol, SeverityLevel>]
      def severity_levels
        @severity_levels ||= build_severity_levels
      end

      # Get severity level for a violation type
      # @param violation_type [Symbol]
      # @return [Symbol, nil] :critical, :high, :medium, :low, or nil
      def severity_for(violation_type)
        severity_levels.each do |name, level|
          return name if level.violation_types.include?(violation_type)
        end
        nil
      end

      # Get weight for a severity level
      # @param level [Symbol]
      # @return [Integer]
      def severity_weight(level)
        severity_levels[level]&.default_weight || 0
      end

      # Get max penalty for a severity level
      # @param level [Symbol]
      # @return [Integer]
      def severity_max_penalty(level)
        severity_levels[level]&.max_penalty || 0
      end

      # =========================================================================
      # Remediation Classification
      # =========================================================================

      # @return [Set<Symbol>] Remediable violation types
      def remediable_types
        @remediable_types ||= Set.new(
          (@hash["remediable_types"] || []).map(&:to_sym),
        )
      end

      # @return [Set<Symbol>] Non-remediable violation types
      def non_remediable_types
        @non_remediable_types ||= Set.new(
          (@hash["non_remediable_types"] || []).map(&:to_sym),
        )
      end

      # @param violation_type [Symbol]
      # @return [Boolean]
      def remediable?(violation_type)
        remediable_types.include?(violation_type)
      end

      # @param violation_type [Symbol]
      # @return [Boolean]
      def non_remediable?(violation_type)
        non_remediable_types.include?(violation_type)
      end

      # =========================================================================
      # Quality Score Formula
      # =========================================================================

      # @return [QualityFormula]
      def quality_formula
        @quality_formula ||= QualityFormula.new(@hash["quality_formula"] || {})
      end

      # =========================================================================
      # Quality Levels
      # =========================================================================

      # @return [Hash<Symbol, QualityLevel>]
      def quality_levels
        @quality_levels ||= build_quality_levels
      end

      # Get quality level name for a score
      # @param score [Integer, Float]
      # @return [Symbol]
      def quality_level_for(score)
        quality_levels.sort_by { |_, v| v.min_score }.reverse_each do |name, level|
          return name if score >= level.min_score
        end
        :critical
      end

      # =========================================================================
      # Size Categories
      # =========================================================================

      # @return [Hash<Symbol, Integer>] Category to threshold in KB
      def size_categories
        @size_categories ||= @hash["size_categories"].to_h do |name, value|
          [name.to_sym, value.to_i]
        end
      end

      # @param size_kb [Float]
      # @return [Symbol]
      def size_category_for(size_kb)
        size_categories.sort_by { |_, v| v }.reverse_each do |name, threshold|
          return name if size_kb >= threshold
        end
        :huge
      end

      # =========================================================================
      # Complexity
      # =========================================================================

      # @return [ComplexityConfig]
      def complexity
        @complexity ||= ComplexityConfig.new(@hash["complexity"] || {})
      end

      # =========================================================================
      # Feature Detection
      # =========================================================================

      # @return [Hash<Symbol, Regexp>]
      def feature_patterns
        @feature_patterns ||= compile_patterns(@hash["feature_patterns"] || {})
      end

      # =========================================================================
      # Content Health
      # =========================================================================

      # @return [ContentHealthConfig]
      def content_health
        @content_health ||= ContentHealthConfig.new(@hash["content_health"] || {})
      end

      private

      def build_severity_levels
        (@hash["severity_levels"] || {}).to_h do |name, config|
          [name.to_sym, SeverityLevel.new(name.to_sym, config)]
        end
      end

      def build_quality_levels
        (@hash["quality_levels"] || {}).to_h do |name, config|
          [name.to_sym, QualityLevel.new(name.to_sym, config)]
        end
      end

      def compile_patterns(patterns_config)
        patterns_config.each_with_object({}) do |(name, pattern), compiled|
          next if pattern.nil? || pattern.empty?

          begin
            compiled[name.to_sym] = Regexp.new(pattern, Regexp::IGNORECASE)
          rescue RegexpError => e
            warn "Warning: Invalid feature pattern for #{name}: #{e.message}"
          end
        end
      end

      def deep_merge(base, other)
        merger = proc { |_key, this_val, other_val|
          if this_val.is_a?(Hash) && other_val.is_a?(Hash)
            this_val.merge(other_val, &merger)
          else
            other_val
          end
        }
        base.merge(other, &merger)
      end

      # =========================================================================
      # Immutable Nested Configuration Objects
      # =========================================================================

      class SeverityLevel
        attr_reader :name, :description, :violation_types, :default_weight, :max_penalty

        def initialize(name, config)
          @name = name
          @description = config["description"]
          @violation_types = config["violation_types"].to_a.map(&:to_sym).freeze
          @default_weight = config["default_weight"].to_i
          @max_penalty = config["max_penalty"].to_i
          freeze
        end

        def ==(other)
          other.is_a?(SeverityLevel) &&
            name == other.name &&
            default_weight == other.default_weight &&
            max_penalty == other.max_penalty
        end
        alias eql? ==
      end

      class QualityLevel
        attr_reader :name, :min_score, :max_score, :description

        def initialize(name, config)
          @name = name
          @min_score = config["min_score"].to_i
          @max_score = config["max_score"]&.to_i
          @description = config["description"]
          freeze
        end

        def ==(other)
          other.is_a?(QualityLevel) &&
            name == other.name &&
            min_score == other.min_score
        end
        alias eql? ==
      end

      class QualityFormula
        attr_reader :error_density_weight, :error_density_max_penalty,
                    :non_remediable_weight, :non_remediable_max_penalty,
                    :critical_weight, :critical_max_penalty,
                    :high_weight, :high_max_penalty,
                    :valid_structure_bonus

        def initialize(config)
          @error_density_weight = config["error_density_weight"].to_f
          @error_density_max_penalty = config["error_density_max_penalty"].to_i
          @non_remediable_weight = config["non_remediable_weight"].to_f
          @non_remediable_max_penalty = config["non_remediable_max_penalty"].to_i
          @critical_weight = config["critical_weight"].to_f
          @critical_max_penalty = config["critical_max_penalty"].to_i
          @high_weight = config["high_weight"].to_f
          @high_max_penalty = config["high_max_penalty"].to_i
          @valid_structure_bonus = config["valid_structure_bonus"].to_i
          freeze
        end
      end

      class ComplexityConfig
        attr_reader :base_element_multiplier, :depth_weight, :max_index,
                    :feature_bonuses

        def initialize(config)
          @base_element_multiplier = config["base_element_multiplier"].to_f
          @depth_weight = config["depth_weight"].to_f
          @max_index = config["max_index"].to_f
          @feature_bonuses = config["feature_bonuses"].to_h do |k, v|
            [k.to_sym, v.to_f]
          end.freeze
          freeze
        end

        def feature_bonus(feature)
          feature_bonuses[feature] || 0.0
        end
      end

      class ContentHealthConfig
        attr_reader :minor_issues_max_errors, :minor_issues_max_severity,
                    :moderate_issues_max_errors, :moderate_issues_any_high,
                    :severe_issues_min_errors, :severe_issues_any_critical

        def initialize(config)
          @minor_issues_max_errors = config["minor_issues_max_errors"].to_i
          @minor_issues_max_severity = config["minor_issues_max_severity"]
          @moderate_issues_max_errors = config["moderate_issues_max_errors"].to_i
          @moderate_issues_any_high = config["moderate_issues_any_high"]
          @severe_issues_min_errors = config["severe_issues_min_errors"].to_i
          @severe_issues_any_critical = config["severe_issues_any_critical"]
          freeze
        end
      end
    end
  end
end
