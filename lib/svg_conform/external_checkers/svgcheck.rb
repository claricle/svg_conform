# frozen_string_literal: true

require_relative "svgcheck/parser"
require_relative "svgcheck/compatibility_engine"
require_relative "svgcheck/report_generator"
require_relative "svgcheck/output_generator"
require_relative "svgcheck/validation_pipeline"
require_relative "svgcheck/report_comparator"

module SvgConform
  module ExternalCheckers
    # SVGCheck external checker integration
    module Svgcheck
      # Main svgcheck checker class
      class Checker < BaseChecker
        SVGCHECK_EXECUTABLE = "python3"
        SVGCHECK_MODULE_PATH = "svgcheck/svgcheck"

        def initialize
          super(name: "svgcheck", version: detect_version)
        end

        def available?
          command_available?(SVGCHECK_EXECUTABLE) &&
            Dir.exist?(SVGCHECK_MODULE_PATH)
        end

        def generate_outputs(input_file, mode: :both)
          generator = OutputGenerator.new(
            svgcheck_exec: SVGCHECK_EXECUTABLE,
            svgcheck_path: SVGCHECK_MODULE_PATH,
          )
          generator.generate(input_file, mode: mode)
        end

        def parse_output(output_content, error_content = nil)
          parser = Parser.new
          parser.parse(output_content, error_content)
        end

        private

        def detect_version
          # Try to detect svgcheck version - placeholder for now
          "unknown"
        end

        def command_available?(command)
          system("which #{command} > /dev/null 2>&1") ||
            system("where #{command} > NUL 2>&1") || # Windows
            File.executable?(command) # Direct path
        end
      end
    end
  end
end
