# frozen_string_literal: true

require "thor"
require "json"
require "yaml"
require "paint"
require_relative "commands/check"
require_relative "commands/svgcheck"
require_relative "commands/profiles"

module SvgConform
  # Thor-based CLI for SvgConform with svgcheck-like functionality
  class Cli < Thor
    def initialize(*args)
      super
    end

    desc "check [*FILES]",
         "Check SVG file(s) validity (single file, multiple files, or directory)"
    long_desc <<~DESC
      Check SVG file validity against a profile.

      MODES:
      1. Single file: svg_conform check file.svg -p PROFILE
      2. Multiple files: svg_conform check *.svg -p PROFILE
      3. Directory: svg_conform check --directory PATH -p PROFILE

      By default, only validates without creating remediated files.
      Use --fix to enable automatic remediation.

      REMEDIATION OUTPUT:
      - Single file: Uses --fix-output (default: FILE.fixed.svg)
      - Multiple files: Requires --output-dir or --in-place
      - Directory: Requires --output-dir or --in-place

      REPORT FORMATS:
      - table: Human-readable (default for single file)
      - json: JSON format using lutaml-model
      - yaml: YAML format using lutaml-model

      EXAMPLES:
        svg_conform check file.svg -p metanorma
        svg_conform check *.svg -p metanorma -f --output-dir fixed/
        svg_conform check -d images/ -p metanorma --report-format json --report-output report.json
        svg_conform check -d images/ -p metanorma -f --in-place --force
    DESC
    option :directory, aliases: "-d", type: :string,
                       desc: "Directory to scan recursively for SVG files"
    option :profile, aliases: "-p", default: "svg_1_2_rfc",
                     desc: "Profile to validate against"
    option :format, default: "table", enum: %w[table yaml json],
                    desc: "Output format (single file mode)"
    option :fix, aliases: "-f", type: :boolean, default: false,
                 desc: "Create remediated files"
    option :output, aliases: "-o", desc: "Output file (single file mode)"
    option :output_dir, type: :string,
                        desc: "Output directory for remediated files (multi-file mode)"
    option :in_place, type: :boolean, default: false,
                      desc: "Replace original files (requires --force)"
    option :force, type: :boolean, default: false,
                   desc: "Confirm destructive operations (required for --in-place)"
    option :fix_output,
           desc: "Output file for remediated SVG (single file mode, default: FILE.fixed.svg)"
    option :report_format, enum: %w[json yaml],
                           desc: "Batch report format (json or yaml)"
    option :report_output, type: :string,
                           desc: "Save detailed batch report to file"
    option :manifest, type: :string,
                      desc: "Manifest file path (default: manifest.json with --fix)"
    option :quiet, aliases: "-q", type: :boolean, default: false,
                   desc: "Suppress per-file output, show summary only"
    option :verbose, aliases: "-v", type: :boolean, default: false,
                     desc: "Show detailed progress"
    def check(*files)
      SvgConform::Commands::Check.new(files, options).execute
    end

    desc "svgcheck SUBCOMMAND", "Svgcheck-related commands (compare, compatibility, generate)"
    subcommand "svgcheck", Commands::Svgcheck

    desc "profiles", "List available validation profiles"
    long_desc <<~DESC
      List all available validation profiles with their descriptions
      and requirements.
    DESC
    option :verbose, aliases: "-v", type: :boolean, default: false,
                     desc: "Show detailed information"
    def profiles
      SvgConform::Commands::Profiles.new(options).execute
    end

    desc "version", "Show version information"
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
