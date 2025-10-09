# frozen_string_literal: true

require_relative "../semantic_comparator"
require_relative "../remediation_runner"

module SvgConform
  module Compatibility
    # Handles SVG-specific analysis operations
    class SvgAnalysisEngine
      def initialize(context, file_processor)
        @context = context
        @file_processor = file_processor
      end

      def analyze_file(filename, svgcheck_report)
        if @context.check_mode?
          analyze_validation(filename, svgcheck_report)
        else
          analyze_repair(filename, svgcheck_report)
        end
      end

      private

      def analyze_validation(filename, svgcheck_report)
        input_file = @file_processor.input_file_path(filename)
        svg_conform_result = run_validation(input_file)
        svg_conform_report = create_conformance_report(filename,
                                                       svg_conform_result)

        if @context.semantic_analysis?
          build_semantic_validation_result(filename, svg_conform_report,
                                           svgcheck_report)
        else
          build_basic_validation_result(filename, svg_conform_report,
                                        svgcheck_report)
        end
      end

      def analyze_repair(filename, svgcheck_report)
        input_file = @file_processor.input_file_path(filename)
        svg_conform_result = run_remediation(input_file, filename)

        if @context.semantic_analysis?
          build_semantic_repair_result(filename, svg_conform_result,
                                       svgcheck_report)
        else
          build_basic_repair_result(filename, svg_conform_result,
                                    svgcheck_report)
        end
      end

      def run_validation(input_file)
        validator = SvgConform::Validator.new
        validator.validate_file(input_file, profile: @context.profile)
      end

      def run_remediation(input_file, filename)
        remediation_runner = SvgConform::RemediationRunner.new(profile: @context.profile)
        svg_content = File.read(input_file)
        remediation_runner.run_remediation(svg_content, filename: filename)
      end

      def create_conformance_report(filename, svg_conform_result)
        SvgConform::ConformanceReport.from_svg_conform_result(
          filename,
          svg_conform_result,
          profile: @context.profile,
          use_svgcheck_mapping: true,
        )
      end

      def build_semantic_validation_result(filename, svg_conform_report,
svgcheck_report)
        validation_comparison = SvgConform::SemanticComparator.compare_validation_results(
          svg_conform_report,
          svgcheck_report,
        )

        ComparisonResult.new(
          filename: filename,
          type: :semantic_validation,
          validation_comparison: validation_comparison,
        )
      end

      def build_basic_validation_result(filename, svg_conform_report,
svgcheck_report)
        ComparisonResult.new(
          filename: filename,
          type: :basic_validation,
          svg_conform_result: svg_conform_report,
          svgcheck_result: svgcheck_report,
        )
      end

      def build_semantic_repair_result(filename, svg_conform_result,
svgcheck_report)
        svg_conform_report = svg_conform_result.generate_conformance_report
        validation_comparison = SvgConform::SemanticComparator.compare_validation_results(
          svg_conform_report,
          svgcheck_report,
        )

        content_comparison = build_content_comparison(svg_conform_result,
                                                      svgcheck_report)
        xml_equivalence = build_xml_equivalence(filename, svg_conform_result)

        ComparisonResult.new(
          filename: filename,
          type: :semantic_repair,
          validation_comparison: validation_comparison,
          content_comparison: content_comparison,
          xml_equivalence: xml_equivalence,
        )
      end

      def build_basic_repair_result(filename, svg_conform_result,
svgcheck_report)
        ComparisonResult.new(
          filename: filename,
          type: :basic_repair,
          svg_conform_result: svg_conform_result,
          svgcheck_result: svgcheck_report,
        )
      end

      def build_content_comparison(svg_conform_result, svgcheck_report)
        return nil unless svgcheck_report.respond_to?(:remediated_content) &&
          svg_conform_result.remediated_content

        SvgConform::SemanticComparator.compare_remediated_content(
          svg_conform_result.remediated_content,
          svgcheck_report.remediated_content,
        )
      end

      def build_xml_equivalence(filename, svg_conform_result)
        return nil unless svg_conform_result.remediated_content

        unless @file_processor.svgcheck_repaired_file_exists?(filename)
          return {
            error: "Svgcheck repaired file not found: #{@file_processor.svgcheck_repaired_file_path(filename)}",
            xml_equivalent: false,
          }
        end

        begin
          svgcheck_content = @file_processor.read_svgcheck_repaired_content(filename)
          compare_xml_content(svg_conform_result.remediated_content,
                              svgcheck_content)
        rescue StandardError => e
          {
            error: "Error comparing XML files: #{e.message}",
            xml_equivalent: false,
          }
        end
      end

      def compare_xml_content(svg_conform_content, svgcheck_content)
        require "equivalent-xml"

        xml_equivalent = EquivalentXml.equivalent?(svg_conform_content, svgcheck_content, {
                                                     element_order: false,
                                                     normalize_whitespace: true,
                                                   })

        if xml_equivalent
          {
            xml_equivalent: true,
            differences: [],
          }
        else
          differences = analyze_xml_differences(svg_conform_content,
                                                svgcheck_content)
          {
            xml_equivalent: false,
            differences: differences,
          }
        end
      end

      def analyze_xml_differences(svg_conform_content, svgcheck_content)
        differences = []

        begin
          require "moxml"
          moxml = Moxml.new

          svg_conform_doc = moxml.parse(svg_conform_content)
          svgcheck_doc = moxml.parse(svgcheck_content)

          svg_conform_root = svg_conform_doc.root
          svgcheck_root = svgcheck_doc.root

          # Compare element names
          if svg_conform_root.name != svgcheck_root.name
            differences << {
              type: :root_element_name,
              svg_conform: svg_conform_root.name,
              svgcheck: svgcheck_root.name,
            }
          end

          # Compare attributes and children recursively
          differences.concat(compare_element_attributes(svg_conform_root,
                                                        svgcheck_root))
          differences.concat(compare_child_elements(svg_conform_root,
                                                    svgcheck_root))
        rescue StandardError => e
          differences << {
            type: :parsing_error,
            error: e.message,
          }
        end

        differences
      end

      def compare_element_attributes(elem1, elem2)
        differences = []
        attrs1 = normalize_attributes(elem1.attributes)
        attrs2 = normalize_attributes(elem2.attributes)
        all_attr_names = (attrs1.keys + attrs2.keys).uniq

        all_attr_names.each do |attr_name|
          val1 = attrs1[attr_name]
          val2 = attrs2[attr_name]

          next unless val1 != val2

          differences << {
            type: :attribute_difference,
            element: elem1.name,
            attribute: attr_name,
            svg_conform: val1,
            svgcheck: val2,
          }
        end

        differences
      end

      def normalize_attributes(attributes)
        return {} if attributes.nil?

        case attributes
        when Hash
          attributes
        when Array
          attributes.each_with_object({}) do |attr, hash|
            if attr.respond_to?(:name) && attr.respond_to?(:value)
              hash[attr.name] = attr.value
            elsif attr.is_a?(Array) && attr.length == 2
              hash[attr[0]] = attr[1]
            end
          end
        else
          {}
        end
      end

      def compare_child_elements(elem1, elem2)
        differences = []
        children1 = elem1.children.select { |child| child.respond_to?(:name) }
        children2 = elem2.children.select { |child| child.respond_to?(:name) }

        if children1.length != children2.length
          differences << {
            type: :child_count_difference,
            element: elem1.name,
            svg_conform_count: children1.length,
            svgcheck_count: children2.length,
          }
        end

        max_children = [children1.length, children2.length].max
        (0...max_children).each do |i|
          child1 = children1[i]
          child2 = children2[i]

          if child1 && child2
            if child1.name == child2.name
              differences.concat(compare_element_attributes(child1, child2))
              differences.concat(compare_child_elements(child1, child2))
            else
              differences << {
                type: :child_element_name,
                parent: elem1.name,
                position: i,
                svg_conform: child1.name,
                svgcheck: child2.name,
              }
            end
          elsif child1
            differences << {
              type: :extra_child_svg_conform,
              parent: elem1.name,
              position: i,
              element: child1.name,
            }
          elsif child2
            differences << {
              type: :extra_child_svgcheck,
              parent: elem1.name,
              position: i,
              element: child2.name,
            }
          end
        end

        differences
      end
    end
  end
end
