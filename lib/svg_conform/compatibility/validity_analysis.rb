# frozen_string_literal: true

require 'lutaml/model'

module SvgConform
  module Compatibility
    # Model for validity analysis results
    class ValidityAnalysis < Lutaml::Model::Serializable
      attribute :svg_conform_valid, :boolean
      attribute :svgcheck_valid, :boolean
      attribute :validity_match, :boolean
      attribute :mismatch_reasons, :string, collection: true
      attribute :requirement_differences, :string, collection: true

      def initialize(svg_conform_valid:, svgcheck_valid:)
        @svg_conform_valid = svg_conform_valid
        @svgcheck_valid = svgcheck_valid
        @validity_match = svg_conform_valid == svgcheck_valid
        @mismatch_reasons = []
        @requirement_differences = []
      end

      def add_mismatch_reason(reason)
        @mismatch_reasons << reason
      end

      def add_requirement_difference(difference)
        @requirement_differences << difference
      end

      def mismatch?
        !@validity_match
      end

      def both_valid?
        @svg_conform_valid && @svgcheck_valid
      end

      def both_invalid?
        !@svg_conform_valid && !@svgcheck_valid
      end

      def svg_conform_stricter?
        !@svg_conform_valid && @svgcheck_valid
      end

      def svgcheck_stricter?
        @svg_conform_valid && !@svgcheck_valid
      end
    end

    # Model for semantic pattern analysis
    class SemanticPattern < Lutaml::Model::Serializable
      attribute :pattern_type, :string
      attribute :svg_conform_message, :string
      attribute :svgcheck_message, :string
      attribute :semantic_key, :string
      attribute :confidence_score, :float
      attribute :mapped, :boolean

      def initialize(pattern_type:, svg_conform_message:, svgcheck_message:)
        @pattern_type = pattern_type
        @svg_conform_message = svg_conform_message
        @svgcheck_message = svgcheck_message
        @mapped = false
        @confidence_score = 0.0
      end

      def map_to_semantic_key(key, confidence = 1.0)
        @semantic_key = key
        @confidence_score = confidence
        @mapped = true
      end

      def unmapped?
        !@mapped
      end
    end

    # Enhanced validity analyzer following model-driven architecture
    class ValidityAnalyzer
      attr_reader :analysis_results

      def initialize
        @analysis_results = []
      end

      def analyze_validity_mismatch(svg_conform_result, svgcheck_result, filename)
        # Handle different result types
        svg_conform_valid = if svg_conform_result.respond_to?(:valid?)
                              svg_conform_result.valid?
                            else
                              svg_conform_result.valid
                            end

        svgcheck_valid = if svgcheck_result.respond_to?(:valid?)
                           svgcheck_result.valid?
                         else
                           svgcheck_result.valid
                         end

        analysis = ValidityAnalysis.new(
          svg_conform_valid: svg_conform_valid,
          svgcheck_valid: svgcheck_valid
        )

        if analysis.mismatch?
          investigate_mismatch_reasons(analysis, svg_conform_result,
                                       svgcheck_result, filename)
        end

        @analysis_results << analysis
        analysis
      end

      def analyze_semantic_patterns(svg_conform_issues, svgcheck_issues)
        patterns = []

        svg_conform_issues.each do |svg_issue|
          svgcheck_issues.each do |svg_issue_check|
            pattern = SemanticPattern.new(
              pattern_type: determine_pattern_type(svg_issue, svg_issue_check),
              svg_conform_message: svg_issue.to_s,
              svgcheck_message: svg_issue_check.to_s
            )

            # Try to map to existing semantic keys
            map_semantic_pattern(pattern)
            patterns << pattern
          end
        end

        patterns
      end

      private

      def investigate_mismatch_reasons(analysis, svg_conform_result,
                                       svgcheck_result, _filename)
        if analysis.svg_conform_stricter?
          analysis.add_mismatch_reason('SvgConform stricter validation')
          analyze_svg_conform_requirements(analysis, svg_conform_result)
        elsif analysis.svgcheck_stricter?
          analysis.add_mismatch_reason('Svgcheck stricter validation')
          analyze_svgcheck_requirements(analysis, svgcheck_result)
        end
      end

      def analyze_svg_conform_requirements(analysis, result)
        # Analyze which specific requirements are failing
        return unless result.respond_to?(:issues)

        result.issues.each do |issue|
          requirement_type = extract_requirement_type(issue)
          analysis.add_requirement_difference(
            "SvgConform requirement: #{requirement_type}"
          )
        end
      end

      def analyze_svgcheck_requirements(analysis, result)
        # Analyze svgcheck specific requirements
        return unless result.respond_to?(:messages)

        result.messages.each do |message|
          requirement_type = extract_svgcheck_requirement_type(message)
          analysis.add_requirement_difference(
            "Svgcheck requirement: #{requirement_type}"
          )
        end
      end

      def extract_requirement_type(issue)
        case issue.to_s
        when /namespace/i
          'namespace_requirement'
        when /viewbox/i
          'viewbox_requirement'
        when /font/i
          'font_requirement'
        when /color/i
          'color_requirement'
        else
          'unknown_requirement'
        end
      end

      def extract_svgcheck_requirement_type(message)
        case message.to_s
        when /namespace/i
          'namespace_validation'
        when /viewbox/i
          'viewbox_validation'
        when /font/i
          'font_validation'
        when /color/i
          'color_validation'
        else
          'unknown_validation'
        end
      end

      def determine_pattern_type(svg_issue, svgcheck_issue)
        svg_type = extract_requirement_type(svg_issue)
        svgcheck_type = extract_svgcheck_requirement_type(svgcheck_issue)

        if svg_type.gsub('_requirement', '') ==
           svgcheck_type.gsub('_validation', '')
          'equivalent_validation'
        else
          'different_validation'
        end
      end

      def map_semantic_pattern(pattern)
        # Enhanced semantic mapping logic
        semantic_key = determine_semantic_key(pattern)
        return unless semantic_key

        confidence = calculate_mapping_confidence(pattern, semantic_key)
        pattern.map_to_semantic_key(semantic_key, confidence)
      end

      def determine_semantic_key(pattern)
        # Use existing semantic comparator logic
        SvgConform::SemanticComparator.new

        # This would need to be enhanced to work with the pattern model
        # For now, return a basic mapping
        case pattern.pattern_type
        when 'equivalent_validation'
          'validation_equivalent'
        when 'different_validation'
          'validation_different'
        end
      end

      def calculate_mapping_confidence(pattern, _semantic_key)
        # Calculate confidence based on pattern similarity
        case pattern.pattern_type
        when 'equivalent_validation'
          0.9
        when 'different_validation'
          0.5
        else
          0.1
        end
      end
    end
  end
end
