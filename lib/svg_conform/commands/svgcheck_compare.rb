# frozen_string_literal: true

require "paint"

module SvgConform
  module Commands
    # Compare command for comparing SvgConform validation with svgcheck reports
    class SvgcheckCompare
      def initialize(file, options)
        @file = file
        @options = options
        # Paint doesn't need initialization like Pastel
      end

      def execute
        # Determine the correct file to validate
        validation_file = determine_validation_file(@file)

        unless File.exist?(validation_file)
          puts Paint["Error: File '#{validation_file}' not found", :red]
          exit 1
        end

        begin
          # Find or use specified svgcheck report
          svgcheck_report_path = find_svgcheck_report
          unless svgcheck_report_path && File.exist?(svgcheck_report_path)
            puts Paint["Error: svgcheck report not found", :red]
            if svgcheck_report_path
              puts Paint["Expected: #{svgcheck_report_path}",
                         :dim]
            end
            exit 1
          end

          # Load svgcheck report using the new external checker parser
          parser = SvgConform::ExternalCheckers::Svgcheck::Parser.new
          error_content = File.read(svgcheck_report_path)
          svgcheck_report = parser.parse(error_content, nil,
                                         filename: File.basename(@file))

          # Generate SvgConform report using the correct validation file
          validator = SvgConform::Validator.new
          result = validator.validate_file(validation_file,
                                           profile: @options[:profile].to_sym)
          svg_conform_report = SvgConform::ConformanceReport.from_svg_conform_result(
            File.basename(@file),
            result,
            profile: @options[:profile].to_sym,
          )

          # Compare the reports
          comparator = SvgConform::ReportComparator.new
          comparator.compare_reports(svg_conform_report, svgcheck_report,
                                     File.basename(@file))
        rescue StandardError => e
          puts Paint["Error: #{e.message}", :red]
          exit 1
        end
      end

      private

      def determine_validation_file(file)
        # If the file is in a Results directory, try to find the original in Tests directory
        if file.include?("/Results/")
          test_file = file.gsub("/Results/", "/Tests/")
          return test_file if File.exist?(test_file)
        end

        # Otherwise use the original file
        file
      end

      def find_svgcheck_report
        return @options[:svgcheck_report] if @options[:svgcheck_report]

        # Auto-detect based on file name
        base_name = File.basename(@file)

        # Try common locations
        possible_paths = [
          "spec/fixtures/svgcheck_reports/#{base_name}.svgcheck.yaml",
          "#{File.dirname(@file)}/#{base_name}.svgcheck.yaml",
          "#{@file}.svgcheck.yaml",
        ]

        possible_paths.find { |path| File.exist?(path) }
      end
    end
  end
end
