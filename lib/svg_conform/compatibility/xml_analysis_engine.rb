# frozen_string_literal: true

require_relative "../semantic_comparator"
require_relative "../remediation_runner"

module SvgConform
  module Compatibility
    # Handles XML-specific analysis operations for embedded SVG elements
    class XmlAnalysisEngine
      def initialize(context, file_processor)
        @context = context
        @file_processor = file_processor
      end

      def analyze_file(filename, svgcheck_report)
        input_file = @file_processor.input_file_path(filename)
        doc = parse_xml_file(input_file)
        return nil unless doc

        svg_elements = extract_svg_elements(doc)
        return nil if svg_elements.empty?

        display_analysis_header(filename, svg_elements.length)
        process_svg_elements(svg_elements, filename, svgcheck_report)
      end

      private

      def parse_xml_file(input_file)
        require "moxml"
        xml_content = File.read(input_file)
        moxml = Moxml.new
        moxml.parse(xml_content)
      rescue StandardError => e
        puts "❌ Error parsing XML file: #{e.message}"
        nil
      end

      def extract_svg_elements(doc)
        svg_elements = doc.xpath("//svg:svg", "svg" => "http://www.w3.org/2000/svg")

        puts "❌ No SVG elements found in XML file" if svg_elements.empty?

        svg_elements
      end

      def display_analysis_header(filename, element_count)
        mode_icon = @context.repair_mode? ? "🔧" : "📋"
        mode_text = @context.repair_mode? ? "Repair Analysis" : "Analysis"

        puts Paint["#{mode_icon} XML File #{mode_text}: #{filename}", :cyan,
                   :bold]
        puts "Found #{element_count} embedded SVG element(s)"
        puts
      end

      def process_svg_elements(svg_elements, filename, svgcheck_report)
        svg_elements.each_with_index do |svg_element, index|
          puts Paint["🔍 Analyzing SVG Element #{index + 1}:", :blue, :bold]
          process_single_svg_element(svg_element, filename, index,
                                     svgcheck_report)
        end
      end

      def process_single_svg_element(svg_element, filename, index,
svgcheck_report)
        svg_content = svg_element.to_xml
        element_filename = "#{filename}#svg#{index + 1}"

        require "tempfile"
        temp_file = Tempfile.new(["embedded_svg", ".svg"])

        begin
          temp_file.write(svg_content)
          temp_file.close

          if @context.repair_mode?
            process_embedded_svg_repair(element_filename, svg_content,
                                        svgcheck_report)
          else
            process_embedded_svg_validation(element_filename, temp_file.path,
                                            svgcheck_report)
          end
        ensure
          temp_file.unlink
        end
      end

      def process_embedded_svg_validation(element_filename, temp_file_path,
svgcheck_report)
        svg_conform_result = run_validation(temp_file_path)
        svg_conform_report = create_conformance_report(element_filename,
                                                       svg_conform_result)

        if @context.semantic_analysis?
          build_semantic_validation_result(element_filename,
                                           svg_conform_report, svgcheck_report)
        else
          build_basic_validation_result(element_filename, svg_conform_report,
                                        svgcheck_report)
        end
      end

      def process_embedded_svg_repair(element_filename, svg_content,
svgcheck_report)
        remediation_runner = SvgConform::RemediationRunner.new(profile: @context.profile)
        svg_conform_result = remediation_runner.run_remediation(svg_content,
                                                                filename: element_filename)

        if @context.semantic_analysis?
          build_semantic_repair_result(element_filename, svg_conform_result,
                                       svgcheck_report)
        else
          build_basic_repair_result(element_filename, svg_conform_result,
                                    svgcheck_report)
        end
      end

      def run_validation(temp_file_path)
        validator = SvgConform::Validator.new
        validator.validate_file(temp_file_path, profile: @context.profile)
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

        ComparisonResult.new(
          filename: filename,
          type: :semantic_repair,
          validation_comparison: validation_comparison,
          content_comparison: content_comparison,
          xml_equivalence: nil, # XML files don't have repaired file comparison
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
    end
  end
end
