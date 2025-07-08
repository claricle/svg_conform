# frozen_string_literal: true

require_relative 'analysis_context'
require_relative 'comparison_result'
require_relative 'file_processor'
require_relative 'svg_analysis_engine'
require_relative 'xml_analysis_engine'
require_relative 'report_formatter'

module SvgConform
  module Compatibility
    # Main orchestrator for compatibility analysis operations
    class CompatibilityAnalyzer
      def initialize(options = {})
        @context = AnalysisContext.new(options)
        @file_processor = FileProcessor.new(@context)
        @svg_engine = SvgAnalysisEngine.new(@context, @file_processor)
        @xml_engine = XmlAnalysisEngine.new(@context, @file_processor)
        @formatter = ReportFormatter.new(@context)
      end

      def run_analysis
        @file_processor.validate_environment

        if @context.single_file_analysis?
          run_single_file_analysis
        else
          run_batch_analysis
        end
      end

      private

      def run_single_file_analysis
        filename = @context.file
        result = analyze_single_file(filename)

        if result
          @formatter.display_single_file_result(result)
          @formatter.write_output_file(result)
        end

        result
      end

      def run_batch_analysis
        files = @file_processor.discover_files
        results = []

        files.each do |filename|
          result = analyze_single_file(filename)
          results << result if result
        end

        @formatter.display_batch_results(results)
        @formatter.write_output_file(results)

        results
      end

      def analyze_single_file(filename)
        unless @file_processor.file_exists?(filename)
          puts "❌ Input file not found: #{filename}"
          return nil
        end

        svgcheck_report = @file_processor.parse_svgcheck_outputs(filename)
        unless svgcheck_report
          puts "❌ Svgcheck outputs not found for: #{filename}"
          return nil
        end

        if @file_processor.xml_file?(filename)
          @xml_engine.analyze_file(filename, svgcheck_report)
        else
          @svg_engine.analyze_file(filename, svgcheck_report)
        end
      rescue StandardError => e
        puts "❌ Error analyzing #{filename}: #{e.message}"
        puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
        nil
      end
    end
  end
end
