# frozen_string_literal: true

require_relative "../compatibility/compatibility_analyzer"

module SvgConform
  module Commands
    # Command for comparing SvgConform with svgcheck compatibility
    class SvgcheckCompatibility
      def initialize(options = {})
        @options = options
      end

      def execute
        validate_options

        analyzer = SvgConform::Compatibility::CompatibilityAnalyzer.new(
          mode: @options[:mode] || @options["mode"] || "check",
          profile: @options[:profile] || @options["profile"] || "svg_1_2_rfc_compatible",
          semantic: @options[:semantic] || @options["semantic"] || false,
          svgcheck_dir: @options[:svgcheck_dir] || @options["svgcheck_dir"] || "spec/fixtures/svgcheck",
          file: @options[:file] || @options["file"],
          output: @options[:output] || @options["output"],
        )

        analyzer.run_analysis
      end

      private

      def validate_options
        mode = @options[:mode] || @options["mode"] || "check"
        raise "Invalid mode: #{mode}. Must be 'check' or 'repair'" unless %w[
          check repair
        ].include?(mode)

        file = @options[:file] || @options["file"]
        return unless file && !file.match?(/\.(svg|xml)$/i)

        raise "File must have .svg or .xml extension: #{file}"
      end
    end
  end
end
