# frozen_string_literal: true

require_relative "comparison/validation_comparator"
require_relative "comparison/content_comparator"

module SvgConform
  # Semantic comparison engine for comparing validation results and remediated content
  #
  # This class provides backward-compatible static methods that delegate to
  # the specialized comparator classes.
  #
  # @deprecated Prefer using ValidationComparator or ContentComparator directly for new code
  class SemanticComparator
    # Instance of validation comparator for delegation
    @validation_comparator = nil
    @content_comparator = nil

    class << self
      # Compare validation results semantically
      # @param svg_conform_report [Object] svg_conform validation report
      # @param svgcheck_report [Object] svgcheck validation report
      # @return [Hash] comparison results with compatibility metrics
      def compare_validation_results(svg_conform_report, svgcheck_report)
        validation_comparator.compare(svg_conform_report, svgcheck_report)
      end

      # Compare remediated SVG content semantically
      # @param svg_conform_content [String] svg_conform remediated SVG
      # @param svgcheck_content [String] svgcheck remediated SVG
      # @return [Hash] comparison results with semantic equivalence metrics
      def compare_remediated_content(svg_conform_content, svgcheck_content)
        content_comparator.compare(svg_conform_content, svgcheck_content)
      end

      # Extract validation features for semantic comparison
      # @param report [Object] validation report
      # @return [Hash] extracted validation features
      def extract_validation_features(report)
        validation_comparator.extract_validation_features(report)
      end

      # Parse SVG safely
      # @param content [String] SVG content
      # @return [Nokogiri::XML::Document, nil] parsed document or nil on error
      def parse_svg_safely(content)
        return nil if content.nil? || content.strip.empty?

        Nokogiri::XML(content, &:strict)
      rescue Nokogiri::XML::SyntaxError
        nil
      end

      # Extract SVG features for semantic comparison
      # @param doc [Nokogiri::XML::Document] SVG document
      # @return [Hash] extracted SVG features
      def extract_svg_features(doc)
        content_comparator.extract_svg_features(doc)
      end

      # Extract requirement types from issues
      # @param issues [Array] list of issue objects
      # @return [Hash] requirement type counts
      def extract_requirement_types(issues)
        validation_comparator.send(:extract_requirement_types, issues)
      end

      # Group issues by semantic meaning
      # @param issues [Array] list of issue objects
      # @return [Hash] grouped issues by semantic category
      def group_issues_semantically(issues)
        Comparison::SemanticExtractor.group_issues_semantically(issues)
      end

      # Compare validity semantically
      # @param valid1 [Boolean] first report validity
      # @param valid2 [Boolean] second report validity
      # @return [Hash] validity comparison result
      def compare_validity(valid1, valid2)
        validation_comparator.send(:compare_validity, valid1, valid2)
      end

      # Compare requirement coverage
      # @param reqs1 [Hash] first report requirements
      # @param reqs2 [Hash] second report requirements
      # @return [Hash] requirement coverage comparison
      def compare_requirement_coverage(reqs1, reqs2)
        validation_comparator.send(:compare_requirement_coverage, reqs1, reqs2)
      end

      # Compare semantic issues
      # @param issues1 [Hash] first report grouped issues
      # @param issues2 [Hash] second report grouped issues
      # @param repair_mode [Boolean] whether both reports are valid
      # @param mixed_mode [Boolean] whether validity differs
      # @return [Hash] semantic issues comparison
      def compare_semantic_issues(issues1, issues2, repair_mode = false, mixed_mode = false)
        validation_comparator.send(:compare_semantic_issues, issues1, issues2, repair_mode, mixed_mode)
      end

      # Create detailed mapping between issues
      # @param issues1 [Hash] first report grouped issues
      # @param issues2 [Hash] second report grouped issues
      # @param repair_mode [Boolean] whether both reports are valid
      # @param mixed_mode [Boolean] whether validity differs
      # @return [Hash] detailed issue mapping
      def create_detailed_mapping(issues1, issues2, repair_mode = false, mixed_mode = false)
        validation_comparator.send(:create_detailed_mapping, issues1, issues2, repair_mode, mixed_mode)
      end

      # Calculate compatibility score
      # @param comparison [Hash] comparison results
      # @return [Float] compatibility score (0.0 to 1.0)
      def calculate_compatibility_score(comparison)
        validation_comparator.send(:calculate_compatibility_score, comparison)
      end

      # Calculate compatibility score for mixed mode scenarios
      # @param comparison [Hash] comparison results
      # @return [Float] compatibility score
      def calculate_mixed_mode_compatibility_score(comparison)
        validation_comparator.send(:calculate_mixed_mode_compatibility_score, comparison)
      end

      # Extract document structure
      # @param doc [Nokogiri::XML::Document] SVG document
      # @return [Hash] structure information
      def extract_structure(doc)
        content_comparator.send(:extract_structure, doc)
      end

      # Extract element hierarchy
      # @param element [Nokogiri::XML::Element] root element
      # @param depth [Integer] current depth (for recursion)
      # @return [Hash] hierarchy information
      def extract_hierarchy(element, depth = 0)
        content_comparator.send(:extract_hierarchy, element, depth)
      end

      # Extract attributes
      # @param doc [Nokogiri::XML::Document] SVG document
      # @return [Hash] attribute information
      def extract_attributes(doc)
        content_comparator.send(:extract_attributes, doc)
      end

      # Extract text content
      # @param doc [Nokogiri::XML::Document] SVG document
      # @return [Hash] content information
      def extract_content(doc)
        content_comparator.send(:extract_content, doc)
      end

      # Extract namespaces
      # @param doc [Nokogiri::XML::Document] SVG document
      # @return [Hash] namespace information
      def extract_namespaces(doc)
        content_comparator.send(:extract_namespaces, doc)
      end

      # Extract style information
      # @param doc [Nokogiri::XML::Document] SVG document
      # @return [Hash] style information
      def extract_styles(doc)
        content_comparator.send(:extract_styles, doc)
      end

      # Parse style attribute
      # @param style_str [String] CSS style string
      # @return [Hash] parsed style properties
      def parse_style_attribute(style_str)
        content_comparator.send(:parse_style_attribute, style_str)
      end

      # Compare structure
      # @param struct1 [Hash] first document structure
      # @param struct2 [Hash] second document structure
      # @return [Hash] structure comparison result
      def compare_structure(struct1, struct2)
        content_comparator.send(:compare_structure, struct1, struct2)
      end

      # Compare hierarchy
      # @param hier1 [Hash] first document hierarchy
      # @param hier2 [Hash] second document hierarchy
      # @return [Boolean] whether hierarchies match
      def compare_hierarchy(hier1, hier2)
        content_comparator.send(:compare_hierarchy, hier1, hier2)
      end

      # Compare attributes
      # @param attrs1 [Hash] first document attributes
      # @param attrs2 [Hash] second document attributes
      # @return [Hash] attribute comparison result
      def compare_attributes(attrs1, attrs2)
        content_comparator.send(:compare_attributes, attrs1, attrs2)
      end

      # Compare content
      # @param content1 [Hash] first document content
      # @param content2 [Hash] second document content
      # @return [Hash] content comparison result
      def compare_content(content1, content2)
        content_comparator.send(:compare_content, content1, content2)
      end

      # Compare namespaces
      # @param ns1 [Hash] first document namespaces
      # @param ns2 [Hash] second document namespaces
      # @return [Hash] namespace comparison result
      def compare_namespaces(ns1, ns2)
        content_comparator.send(:compare_namespaces, ns1, ns2)
      end

      # Compare styles
      # @param styles1 [Hash] first document styles
      # @param styles2 [Hash] second document styles
      # @return [Hash] style comparison result
      def compare_styles(styles1, styles2)
        content_comparator.send(:compare_styles, styles1, styles2)
      end

      # Compare style semantics
      # @param styles1 [Array] first document style array
      # @param styles2 [Array] second document style array
      # @return [Boolean] whether styles are semantically equivalent
      def compare_style_semantics(styles1, styles2)
        content_comparator.send(:compare_style_semantics, styles1, styles2)
      end

      # Calculate semantic equivalence
      # @param features1 [Hash] first document features
      # @param features2 [Hash] second document features
      # @return [Hash] semantic equivalence metrics
      def calculate_semantic_equivalence(features1, features2)
        content_comparator.send(:calculate_semantic_equivalence, features1, features2)
      end

      # Utility methods for normalization (delegated to Normalizer module)
      # @param namespace [String] namespace to normalize
      # @return [String] normalized namespace
      def normalize_namespace(namespace)
        Comparison::Normalizer.normalize_namespace(namespace)
      end

      # @param value [String] value to normalize
      # @return [String] normalized value
      def normalize_value(value)
        Comparison::Normalizer.normalize_value(value)
      end

      # @param color [String] color value to normalize
      # @return [String] normalized color
      def normalize_color_value(color)
        Comparison::Normalizer.normalize_color_value(color)
      end

      # @param message [String] message to normalize
      # @return [String] normalized message
      def normalize_message(message)
        Comparison::Normalizer.normalize_message(message)
      end

      # @param value [String] attribute value to normalize
      # @return [String] normalized attribute value
      def normalize_attribute_value(value)
        Comparison::Normalizer.normalize_attribute_value(value)
      end

      # @param value [String] style value to normalize
      # @return [String] normalized style value
      def normalize_style_value(value)
        Comparison::Normalizer.normalize_style_value(value)
      end

      private

      # Get or create validation comparator instance
      # @return [Comparison::ValidationComparator] validator instance
      def validation_comparator
        @validation_comparator ||= Comparison::ValidationComparator.new
      end

      # Get or create content comparator instance
      # @return [Comparison::ContentComparator] content comparator instance
      def content_comparator
        @content_comparator ||= Comparison::ContentComparator.new
      end
    end
  end
end
