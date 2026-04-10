# frozen_string_literal: true

require "thor"
require_relative "../image_quality_analyzer"

module SvgConform
  module Commands
    # Quality command for SVG image quality analysis
    class Quality
      class QualityError < Thor::Error; end
      class FileNotFoundError < QualityError; end
      class DirectoryNotFoundError < QualityError; end

      def initialize(options)
        @options = options
      end

      def execute
        # This is a subcommand runner - actual logic is in subcommands
        raise QualityError, "No subcommand specified"
      end

      private

      def load_config
        return nil unless @options[:config]

        QualityMetrics::Configuration.from_yaml(@options[:config])
      end

      def analyzer
        @analyzer ||= ImageQualityAnalyzer.new(config: load_config)
      end

      def ensure_file_exists(path)
        return if File.exist?(path)

        raise FileNotFoundError, "File not found: #{path}"
      end

      def ensure_dir_exists(path)
        return if File.directory?(path)

        raise DirectoryNotFoundError, "Directory not found: #{path}"
      end

      def generate_csv_from_batch(batch_report)
        return "" if batch_report.reports.empty?

        headers = %w[
          file_path quality_score quality_level error_count remediable_errors
          non_remediable_errors critical_errors high_errors medium_errors low_errors
          element_count file_size_kb complexity_index content_health size_category
          has_base64 has_foreign_ns has_masks has_clip_paths has_external_refs
        ]

        lines = [headers.join(",")]

        batch_report.reports.each do |report|
          row = headers.map { |h| csv_value(report.public_send(h.to_sym)) }
          lines << row.join(",")
        end

        lines.join("\n")
      end

      def csv_value(value)
        return "" if value.nil?
        return "true" if value == true
        return "false" if value == false

        str = value.to_s
        if str.include?(",") || str.include?('"') || str.include?("\n")
          "\"#{str.gsub('"', '""')}\""
        else
          str
        end
      end
    end

    # Thor-based subcommands for quality analysis
    class QualityCLI < Thor
      class_option :config, type: :string,
                            desc: "Path to custom quality metrics YAML config"
      class_option :profile, type: :string, default: "svg_1_2_rfc",
                             desc: "Validation profile to use"

      desc "analyze FILE", "Analyze a single SVG file"
      method_option :format, type: :string, default: "terminal",
                             enum: %w[terminal yaml json],
                             desc: "Output format: terminal (colorful), yaml, or json"
      def analyze(file_path)
        ensure_file_exists(file_path)

        config = load_config(options[:config])
        analyzer = ImageQualityAnalyzer.new(config: config)

        report = analyzer.analyze(file_path, profile: options[:profile].to_sym)

        output = case options[:format]
                 when "yaml" then report.to_yaml
                 when "json" then report.to_json
                 else report.render
                 end

        puts output
      end

      desc "batch DIRECTORY", "Analyze all SVG files in a directory"
      method_option :pattern, type: :string, default: "**/*.svg",
                              desc: "File pattern to match"
      method_option :output, type: :string,
                             desc: "Output file (default: stdout)"
      method_option :format, type: :string, default: "terminal",
                             enum: %w[terminal yaml csv json],
                             desc: "Output format: terminal (summary), yaml (full), csv, or json"
      method_option :progress, type: :boolean, default: false,
                               desc: "Show progress output"
      method_option :summary_only, type: :boolean, default: false,
                                   desc: "For terminal format, show only summary without individual reports"
      def batch(directory)
        ensure_dir_exists(directory)

        config = load_config(options[:config])
        analyzer = ImageQualityAnalyzer.new(config: config)

        puts "Analyzing SVG files in #{directory}..." if options[:progress]

        batch_report = analyzer.analyze_batch(
          directory,
          pattern: options[:pattern],
          profile: options[:profile].to_sym,
          progress: options[:progress],
        )

        output = case options[:format]
                 when "yaml" then batch_report.to_yaml
                 when "csv" then generate_csv_from_batch(batch_report)
                 when "json" then batch_report.to_json
                 else
                   if options[:summary_only]
                     batch_report.render
                   else
                     lines = []
                     batch_report.reports.each do |report|
                       lines << report.render
                       lines << ""
                     end
                     lines << batch_report.render
                     lines.join("\n")
                   end
                 end

        if options[:output]
          File.write(options[:output], output)
          puts "\nReport written to #{options[:output]}"
        else
          puts output
        end
      end

      desc "summary FILE_OR_DIRECTORY",
           "Show quality summary for file or directory (always uses terminal output)"
      method_option :format, type: :string, default: "terminal",
                             enum: %w[terminal yaml],
                             desc: "Output format: terminal (colorful) or yaml"
      def summary(path)
        config = load_config(options[:config])
        analyzer = ImageQualityAnalyzer.new(config: config)

        if File.directory?(path)
          batch_report = analyzer.analyze_batch(
            path,
            pattern: "**/*.svg",
            profile: options[:profile].to_sym,
            progress: false,
          )

          output = case options[:format]
                   when "yaml" then batch_report.to_yaml
                   else batch_report.render
                   end
        else
          report = analyzer.analyze(path, profile: options[:profile].to_sym)

          output = case options[:format]
                   when "yaml" then report.to_yaml
                   else report.render
                   end
        end

        puts output
      end

      private

      def load_config(config_path)
        return nil unless config_path

        QualityMetrics::Configuration.from_yaml(config_path)
      end

      def ensure_file_exists(path)
        return if File.exist?(path)

        raise Thor::Error, "File not found: #{path}"
      end

      def ensure_dir_exists(path)
        return if File.directory?(path)

        raise Thor::Error, "Directory not found: #{path}"
      end

      def generate_csv_from_batch(batch_report)
        return "" if batch_report.reports.empty?

        headers = %w[
          file_path quality_score quality_level error_count remediable_errors
          non_remediable_errors critical_errors high_errors medium_errors low_errors
          element_count file_size_kb complexity_index content_health size_category
          has_base64 has_foreign_ns has_masks has_clip_paths has_external_refs
        ]

        lines = [headers.join(",")]

        batch_report.reports.each do |report|
          row = headers.map { |h| csv_value(report.public_send(h.to_sym)) }
          lines << row.join(",")
        end

        lines.join("\n")
      end

      def csv_value(value)
        return "" if value.nil?
        return "true" if value == true
        return "false" if value == false

        str = value.to_s
        if str.include?(",") || str.include?('"') || str.include?("\n")
          "\"#{str.gsub('"', '""')}\""
        else
          str
        end
      end
    end
  end
end
