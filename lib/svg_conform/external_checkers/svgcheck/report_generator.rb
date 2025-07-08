# frozen_string_literal: true

require_relative 'parser'
require_relative '../../conformance_report'

module SvgConform
  module ExternalCheckers
    module Svgcheck
      # Generates ConformanceReport objects from svgcheck outputs
      class ReportGenerator
        def initialize(parser: nil)
          @parser = parser || Parser.new
        end

        # Generate a report from svgcheck output files
        def generate_from_files(filename, output_file: nil, error_file: nil, code_file: nil)
          output_content = output_file && File.exist?(output_file) ? File.read(output_file) : nil
          error_content = error_file && File.exist?(error_file) ? File.read(error_file) : nil
          exit_code = code_file && File.exist?(code_file) ? File.read(code_file).strip.to_i : 0

          generate_from_content(filename, output_content, error_content, exit_code)
        end

        # Generate a report from svgcheck output content
        def generate_from_content(filename, output_content, error_content = nil, exit_code = 0)
          # svgcheck writes validation messages to stderr, not stdout
          # So we use error_content as the main content to parse
          main_content = error_content || output_content

          report = @parser.parse(main_content, nil, filename: filename)

          # Set additional metadata
          report.profile = 'svg_1_2_rfc' # svgcheck is specifically for SVG 1.2 RFC
          report.version = detect_svgcheck_version

          # Use exit code to determine validity if needed
          if exit_code != 0 && report.valid
            report.valid = false
          end

          report
        end

        # Generate reports for both check and repair modes
        def generate_comparative_reports(filename, check_outputs: nil, repair_outputs: nil)
          reports = {}

          if check_outputs
            reports[:check] = generate_from_content(
              filename,
              check_outputs[:stdout],
              check_outputs[:stderr],
              check_outputs[:exit_code]
            )
          end

          if repair_outputs
            reports[:repair] = generate_from_content(
              filename,
              repair_outputs[:stdout],
              repair_outputs[:stderr],
              repair_outputs[:exit_code]
            )
          end

          reports
        end

        private

        def detect_svgcheck_version
          # Try to detect svgcheck version - placeholder for now
          'unknown'
        end
      end
    end
  end
end
