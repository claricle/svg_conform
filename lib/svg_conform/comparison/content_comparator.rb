# frozen_string_literal: true

require "nokogiri"
require_relative "normalizer"

module SvgConform
  module Comparison
    # Content comparison engine for comparing remediated SVG documents
    # Compares SVG structure, attributes, styles, and content semantically
    class ContentComparator
      include Normalizer

      # Compare remediated SVG content semantically
      # @param svg_conform_content [String] svg_conform remediated SVG
      # @param svgcheck_content [String] svgcheck remediated SVG
      # @return [Hash] comparison results with semantic equivalence metrics
      def compare(svg_conform_content, svgcheck_content)
        # Parse both SVG documents
        svg_conform_doc = parse_svg_safely(svg_conform_content)
        svgcheck_doc = parse_svg_safely(svgcheck_content)

        return { error: "Failed to parse SVG content" } if svg_conform_doc.nil? || svgcheck_doc.nil?

        # Extract semantic features from both documents
        svg_conform_features = extract_svg_features(svg_conform_doc)
        svgcheck_features = extract_svg_features(svgcheck_doc)

        # Compare features
        {
          structure_match: compare_structure(svg_conform_features[:structure],
                                             svgcheck_features[:structure]),
          attributes_match: compare_attributes(svg_conform_features[:attributes],
                                              svgcheck_features[:attributes]),
          content_match: compare_content(svg_conform_features[:content],
                                         svgcheck_features[:content]),
          namespace_match: compare_namespaces(svg_conform_features[:namespaces],
                                              svgcheck_features[:namespaces]),
          style_match: compare_styles(svg_conform_features[:styles],
                                      svgcheck_features[:styles]),
          semantic_equivalence: calculate_semantic_equivalence(
            svg_conform_features, svgcheck_features
          ),
        }
      end

      # Extract SVG features for content comparison
      # @param doc [Nokogiri::XML::Document] SVG document
      # @return [Hash] extracted SVG features
      def extract_svg_features(doc)
        {
          structure: extract_structure(doc),
          attributes: extract_attributes(doc),
          content: extract_content(doc),
          namespaces: extract_namespaces(doc),
          styles: extract_styles(doc),
        }
      end

      # Extract structure information from SVG document
      # @param doc [Nokogiri::XML::Document] SVG document
      # @return [Hash] structure information
      def extract_structure(doc)
        root = doc.root
        return {} unless root

        {
          root_element: root.name,
          element_count: doc.xpath(".//*").length,
          hierarchy: extract_hierarchy(doc),
          depth: calculate_max_depth(doc),
        }
      end

      # Extract hierarchy information from SVG document
      # @param doc [Nokogiri::XML::Document] SVG document
      # @return [Hash] hierarchy information
      def extract_hierarchy(doc)
        root = doc.root
        return {} unless root

        hierarchy = {}
        root.traverse do |node|
          next unless node.element?

          parent_name = node.parent&.name || "root"
          hierarchy[parent_name] ||= []
          hierarchy[parent_name] << node.name unless hierarchy[parent_name].include?(node.name)
        end

        hierarchy
      end

      # Calculate maximum depth of SVG document
      # @param doc [Nokogiri::XML::Document] SVG document
      # @return [Integer] maximum depth
      def calculate_max_depth(doc)
        max_depth = 0

        doc.traverse do |node|
          next unless node.element?

          depth = node.ancestors.length
          max_depth = depth if depth > max_depth
        end

        max_depth
      end

      # Extract attribute information from SVG document
      # @param doc [Nokogiri::XML::Document] SVG document
      # @return [Hash] attribute information
      def extract_attributes(doc)
        attributes = {}

        doc.xpath(".//@*").each do |attr|
          attributes[attr.name] ||= []
          attributes[attr.name] << normalize_attribute_value(attr.value)
        end

        attributes
      end

      # Extract content information from SVG document
      # @param doc [Nokogiri::XML::Document] SVG document
      # @return [Hash] content information
      def extract_content(doc)
        texts = doc.xpath(".//text()").map(&:text).select(&:strip?)

        {
          text_nodes: texts.length,
          text_content: texts.join(" ").strip[0..200], # First 200 chars
        }
      end

      # Extract namespace information from SVG document
      # @param doc [Nokogiri::XML::Document] SVG document
      # @return [Hash] namespace information
      def extract_namespaces(doc)
        namespaces = doc.namespaces

        # Normalize namespace URIs for comparison
        normalized = {}
        namespaces.each do |prefix, uri|
          normalized[normalize_namespace(prefix)] = normalize_namespace(uri)
        end

        normalized
      end

      # Extract style information from SVG document
      # @param doc [Nokogiri::XML::Document] SVG document
      # @return [Hash] style information
      def extract_styles(doc)
        styles = {}

        # Extract style attributes
        doc.xpath(".//@style").each do |style_attr|
          parsed = parse_style_attribute(style_attr.value)
          parsed.each do |property, value|
            styles[property] ||= []
            styles[property] << normalize_style_value(value)
          end
        end

        styles
      end

      # Parse style attribute into properties
      # @param style_string [String] CSS style string
      # @return [Hash] parsed style properties
      def parse_style_attribute(style_string)
        return {} if style_string.nil? || style_string.empty?

        properties = {}
        style_string.split(";").each do |declaration|
          next if declaration.strip.empty?

          parts = declaration.split(":", 2)
          next unless parts.length == 2

          property = parts[0].strip
          value = parts[1].strip
          properties[property] = value
        end

        properties
      end

      # Compare structure between two SVG documents
      # @param structure1 [Hash] first document structure
      # @param structure2 [Hash] second document structure
      # @return [Hash] structure comparison result
      def compare_structure(structure1, structure2)
        {
          root_match: structure1[:root_element] == structure2[:root_element],
          element_count_difference: (structure1[:element_count] || 0) - (structure2[:element_count] || 0),
          depth_match: structure1[:depth] == structure2[:depth],
          hierarchy_match: structure1[:hierarchy] == structure2[:hierarchy],
        }
      end

      # Compare attributes between two SVG documents
      # @param attrs1 [Hash] first document attributes
      # @param attrs2 [Hash] second document attributes
      # @return [Hash] attribute comparison result
      def compare_attributes(attrs1, attrs2)
        all_attrs = (attrs1.keys | attrs2.keys).sort

        matches = all_attrs.count do |attr|
          vals1 = attrs1[attr] || []
          vals2 = attrs2[attr] || []
          vals1.sort == vals2.sort
        end

        {
          match_count: matches,
          total_count: all_attrs.length,
          match_ratio: all_attrs.empty? ? 1.0 : matches.to_f / all_attrs.length,
          only_in_first: all_attrs.select { |a| attrs1.key?(a) && !attrs2.key?(a) },
          only_in_second: all_attrs.select { |a| !attrs1.key?(a) && attrs2.key?(a) },
        }
      end

      # Compare content between two SVG documents
      # @param content1 [Hash] first document content
      # @param content2 [Hash] second document content
      # @return [Hash] content comparison result
      def compare_content(content1, content2)
        {
          text_count_match: content1[:text_nodes] == content2[:text_nodes],
          content_similarity: calculate_text_similarity(content1[:text_content],
                                                        content2[:text_content]),
        }
      end

      # Compare namespaces between two SVG documents
      # @param ns1 [Hash] first document namespaces
      # @param ns2 [Hash] second document namespaces
      # @return [Hash] namespace comparison result
      def compare_namespaces(ns1, ns2)
        all_ns = (ns1.keys | ns2.keys).sort

        matches = all_ns.count { |ns| ns1[ns] == ns2[ns] }

        {
          match_count: matches,
          total_count: all_ns.length,
          match_ratio: all_ns.empty? ? 1.0 : matches.to_f / all_ns.length,
          only_in_first: all_ns.select { |n| ns1.key?(n) && !ns2.key?(n) },
          only_in_second: all_ns.select { |n| !ns1.key?(n) && ns2.key?(n) },
        }
      end

      # Compare styles between two SVG documents
      # @param styles1 [Hash] first document styles
      # @param styles2 [Hash] second document styles
      # @return [Hash] style comparison result
      def compare_styles(styles1, styles2)
        all_styles = (styles1.keys | styles2.keys).sort

        matches = all_styles.count do |style|
          vals1 = styles1[style] || []
          vals2 = styles2[style] || []
          vals1.sort == vals2.sort
        end

        {
          match_count: matches,
          total_count: all_styles.length,
          match_ratio: all_styles.empty? ? 1.0 : matches.to_f / all_styles.length,
          only_in_first: all_styles.select { |s| styles1.key?(s) && !styles2.key?(s) },
          only_in_second: all_styles.select { |s| !styles1.key?(s) && styles2.key?(s) },
        }
      end

      # Compare style semantics between two style sets
      # @param styles1 [Hash] first document styles
      # @param styles2 [Hash] second document styles
      # @return [Hash] style semantic comparison
      def compare_style_semantics(styles1, styles2)
        # Check if styles are semantically equivalent
        semantic_matches = []

        (styles1.keys | styles2.keys).each do |property|
          vals1 = styles1[property] || []
          vals2 = styles2[property] || []

          # Normalize values for comparison
          normalized1 = vals1.map { |v| normalize_style_value(v) }.sort.uniq
          normalized2 = vals2.map { |v| normalize_style_value(v) }.sort.uniq

          semantic_matches << (normalized1 == normalized2)
        end

        {
          total_properties: (styles1.keys | styles2.keys).length,
          semantic_matches: semantic_matches.count(true),
          semantic_ratio: semantic_matches.empty? ? 1.0 : semantic_matches.count(true).to_f / semantic_matches.length,
        }
      end

      # Calculate semantic equivalence between two SVG documents
      # @param features1 [Hash] first document features
      # @param features2 [Hash] second document features
      # @return [Hash] semantic equivalence metrics
      def calculate_semantic_equivalence(features1, features2)
        structure = compare_structure(features1[:structure], features2[:structure])
        attrs = compare_attributes(features1[:attributes], features2[:attributes])
        content = compare_content(features1[:content], features2[:content])
        ns = compare_namespaces(features1[:namespaces], features2[:namespaces])
        styles = compare_styles(features1[:styles], features2[:styles])

        # Calculate overall semantic equivalence score
        weights = {
          structure: 0.3,
          attributes: 0.25,
          content: 0.15,
          namespaces: 0.1,
          styles: 0.2,
        }

        equivalence = 0.0
        equivalence += weights[:structure] * structure[:hierarchy_match] ? 1.0 : 0.0
        equivalence += weights[:attributes] * attrs[:match_ratio]
        equivalence += weights[:content] * content[:content_similarity]
        equivalence += weights[:namespaces] * ns[:match_ratio]
        equivalence += weights[:styles] * styles[:match_ratio]

        {
          overall_score: equivalence.clamp(0.0, 1.0),
          component_scores: {
            structure: structure,
            attributes: attrs,
            content: content,
            namespaces: ns,
            styles: styles,
          },
        }
      end

      # Calculate text similarity using simple algorithm
      # @param text1 [String] first text
      # @param text2 [String] second text
      # @return [Float] similarity score (0.0 to 1.0)
      def calculate_text_similarity(text1, text2)
        return 1.0 if text1 == text2
        return 0.0 if text1.nil? || text2.nil?

        # Simple word-based similarity
        words1 = text1.downcase.split(/\s+/)
        words2 = text2.downcase.split(/\s+/)

        return 1.0 if words1.empty? && words2.empty?

        intersection = (words1 & words2).length
        union = (words1 | words2).length

        return 0.0 if union.zero?

        intersection.to_f / union
      end

      private

      # Parse SVG safely with error handling
      # @param content [String] SVG content
      # @return [Nokogiri::XML::Document, nil] parsed document or nil on error
      def parse_svg_safely(content)
        Nokogiri::XML(content)
      rescue Nokogiri::XML::SyntaxError
        nil
      end
    end
  end
end
