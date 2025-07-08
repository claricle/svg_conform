# frozen_string_literal: true

require 'thor'
require 'json'
require 'yaml'
require 'paint'
require_relative 'commands/check'
require_relative 'commands/compare'
require_relative 'commands/generate_svgcheck'
require_relative 'commands/compatibility'
require_relative 'commands/profiles'

module SvgConform
  # Thor-based CLI for SvgConform with svgcheck-like functionality
  class Cli < Thor
    def initialize(*args)
      super
    end

    desc 'check FILE', 'Check SVG file validity (svgcheck-like functionality)'
    long_desc <<~DESC
      Check SVG file validity against a profile, similar to svgcheck.

      By default, only validates without creating remediated files.
      Use --fix to create remediated files.

      Output formats:
      - table: Human-readable table format (default)
      - yaml: YAML format
      - json: JSON format
    DESC
    option :profile, aliases: '-p', default: 'svg_1_2_rfc', desc: 'Profile to validate against'
    option :format, aliases: '-f', default: 'table', enum: %w[table yaml json], desc: 'Output format'
    option :output, aliases: '-o', desc: 'Output file (default: stdout)'
    option :fix, type: :boolean, default: false, desc: 'Create remediated file'
    option :fix_output, desc: 'Output file for remediated SVG (default: FILE.fixed.svg)'
    def check(file)
      SvgConform::Commands::Check.new(file, options).execute
    end

    desc 'compare FILE', 'Compare SvgConform validation with svgcheck report'
    long_desc <<~DESC
      Compare SvgConform validation results with existing svgcheck reports.

      This command looks for a corresponding .svgcheck.yaml file and compares
      the validation results, showing differences in a detailed table format.
    DESC
    option :profile, aliases: '-p', default: 'svg_1_2_rfc', desc: 'Profile to validate against'
    option :svgcheck_report, desc: 'Path to svgcheck report (default: auto-detect)'
    def compare(file)
      SvgConform::Commands::Compare.new(file, options).execute
    end

    desc 'generate-svgcheck', 'Generate svgcheck outputs using Open3'
    long_desc <<~DESC
      Generate svgcheck outputs for test files by running svgcheck on them.

      By default, processes all test files in svgcheck/svgcheck/Tests/
      and generates BOTH check and repair outputs in separate subdirectories:
      - spec/fixtures/svgcheck/check/ - Check-only outputs (validation without remediation)
      - spec/fixtures/svgcheck/repair/ - Repair outputs (validation + remediation)

      Check mode generates:
      - {filename}.out - validation messages from svgcheck
      - {filename}.err - error messages from svgcheck
      - {filename}.code - exit status from svgcheck

      Repair mode generates all of the above plus:
      - {filename}.file - remediated SVG content

      Use --mode to specify 'check', 'repair', or 'both' (default: both).
      Use --single-file to process just one file.
      Use --fixtures-path to specify a different output directory.
      Use --svgcheck-exec to specify path to svgcheck executable.
    DESC
    option :mode, aliases: '-m', default: 'both', enum: %w[check repair both],
                  desc: 'Generation mode: check, repair, or both'
    option :svgcheck_exec, desc: 'Path to svgcheck executable (default: svgcheck from PATH)'
    option :fixtures_path, desc: 'Output directory (default: spec/fixtures/svgcheck)'
    option :single_file, aliases: '-f', desc: 'Process single file only'
    option :force, type: :boolean, default: false, desc: 'Overwrite existing outputs'
    option :verbose, aliases: '-v', type: :boolean, default: false, desc: 'Verbose output'
    def generate_svgcheck
      SvgConform::Commands::GenerateSvgcheck.new(options).execute
    end

    desc 'compatibility', 'Run comprehensive svgcheck compatibility analysis'
    long_desc <<~DESC
      Run a comprehensive analysis comparing SvgConform validation results
      with svgcheck outputs in check or repair mode.

      MODES:
      - check: Compare validation results using svgcheck check mode outputs
      - repair: Compare remediation results using svgcheck repair mode outputs

      COMPARISON TYPES:
      - basic: Simple comparison of validation results and error counts
      - semantic: Deep semantic comparison understanding validation message meanings

      Use --file to analyze a specific file instead of all test files.
      Use --svgcheck-dir to specify where to find svgcheck outputs.

      This generates a detailed compatibility report showing how well
      SvgConform matches svgcheck's validation and remediation behavior.

      Examples:
        svg_conform compatibility --mode check --semantic
        svg_conform compatibility --mode repair --file viewBox-none.svg
        svg_conform compatibility --mode both --output report.txt
    DESC
    option :profile, aliases: '-p', default: 'svg_1_2_rfc', desc: 'Profile to validate against'
    option :output, aliases: '-o', desc: 'Output file for detailed report'
    option :file, aliases: '-f', desc: 'Analyze specific file instead of all test files'
    option :mode, aliases: '-m', default: 'check', enum: %w[check repair],
                  desc: 'Comparison mode: check (validation) or repair (remediation)'
    option :semantic, type: :boolean, default: false,
                      desc: 'Use semantic comparison (understands validation message meanings)'
    option :svgcheck_dir, aliases: '-d', default: 'spec/fixtures/svgcheck',
                          desc: 'Directory containing svgcheck outputs (default: spec/fixtures/svgcheck)'
    def compatibility
      SvgConform::Commands::Compatibility.new(options).execute
    end

    desc 'profiles', 'List available validation profiles'
    long_desc <<~DESC
      List all available validation profiles with their descriptions
      and requirements.
    DESC
    option :verbose, aliases: '-v', type: :boolean, default: false, desc: 'Show detailed information'
    def profiles
      SvgConform::Commands::Profiles.new(options).execute
    end

    desc 'version', 'Show version information'
    def version
      puts "SvgConform #{SvgConform::VERSION}"
    end

    private

    def method_missing(method_name, *_args)
      puts Paint["Unknown command: #{method_name}", :red]
      puts
      help
      exit 1
    end
  end
end
