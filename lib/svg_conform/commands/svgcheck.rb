# frozen_string_literal: true

require "thor"
require "paint"
require_relative "svgcheck_compare"
require_relative "svgcheck_compatibility"
require_relative "svgcheck_generate"

module SvgConform
  module Commands
    # Svgcheck subcommand for svgcheck-related operations
    class Svgcheck < Thor
      desc "compare FILE", "Compare SvgConform validation with svgcheck report"
      long_desc <<~DESC
        Compare SvgConform validation results with existing svgcheck reports.

        This command looks for a corresponding .svgcheck.yaml file and compares
        the validation results, showing differences in a detailed table format.
      DESC
      option :profile, aliases: "-p", default: "svg_1_2_rfc",
                       desc: "Profile to validate against"
      option :svgcheck_report,
             desc: "Path to svgcheck report (default: auto-detect)"
      def compare(file)
        SvgConform::Commands::SvgcheckCompare.new(file, options).execute
      end

      desc "compatibility", "Run comprehensive svgcheck compatibility analysis"
      long_desc <<~DESC
        Run a comprehensive analysis comparing SvgConform validation results
        with svgcheck outputs in check or repair mode.

        MODES:
        - check: Compare validation results using svgcheck check mode outputs
        - repair: Compare remediation results using svgcheck repair mode outputs

        Use --file to analyze a specific file instead of all test files.
        Use --svgcheck-dir to specify where to find svgcheck outputs.

        Examples:
          svg_conform svgcheck compatibility --mode check
          svg_conform svgcheck compatibility --file viewBox-none.svg
      DESC
      option :profile, aliases: "-p", default: "svg_1_2_rfc",
                       desc: "Profile to validate against"
      option :output, aliases: "-o", desc: "Output file for detailed report"
      option :file, aliases: "-f",
                    desc: "Analyze specific file instead of all test files"
      option :mode, aliases: "-m", default: "check", enum: %w[check repair],
                    desc: "Comparison mode: check or repair"
      option :semantic, type: :boolean, default: false,
                        desc: "Use semantic comparison"
      option :svgcheck_dir, aliases: "-d", default: "spec/fixtures/svgcheck",
                            desc: "Directory containing svgcheck outputs"
      def compatibility
        SvgConform::Commands::SvgcheckCompatibility.new(options).execute
      end

      desc "generate", "Generate svgcheck outputs"
      long_desc <<~DESC
        Generate svgcheck outputs for test files by running svgcheck on them.

        By default, processes all test files in svgcheck/svgcheck/Tests/
        and generates BOTH check and repair outputs in separate subdirectories.

        Examples:
          svg_conform svgcheck generate
          svg_conform svgcheck generate --mode check
          svg_conform svgcheck generate --single-file example.svg
      DESC
      option :mode, aliases: "-m", default: "both", enum: %w[check repair both],
                    desc: "Generation mode: check, repair, or both"
      option :svgcheck_exec,
             desc: "Path to svgcheck executable"
      option :fixtures_path,
             desc: "Output directory (default: spec/fixtures/svgcheck)"
      option :single_file, aliases: "-f", desc: "Process single file only"
      option :force, type: :boolean, default: false,
                     desc: "Overwrite existing outputs"
      option :verbose, aliases: "-v", type: :boolean, default: false,
                       desc: "Verbose output"
      def generate
        SvgConform::Commands::SvgcheckGenerate.new(options).execute
      end
    end
  end
end
