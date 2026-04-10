# frozen_string_literal: true

require_relative "quality_metrics/configuration"
require_relative "quality_metrics/error_breakdown"
require_relative "quality_metrics/feature_flags"
require_relative "quality_metrics/quality_score"
require_relative "quality_metrics/complexity_metrics"
require_relative "quality_metrics/quality_result"
require_relative "quality_metrics/error_analyzer"
require_relative "quality_metrics/feature_detector"
require_relative "quality_metrics/complexity_calculator"
require_relative "quality_metrics/quality_calculator"
require_relative "quality_metrics/quality_report_formatter"
require_relative "quality_report"

module SvgConform
  # Analyzes SVG image quality across multiple dimensions.
  #
  # Main entry point for quality analysis. Analyzes files and returns
  # immutable QualityResult value objects that can be serialized or rendered.
  #
  # @example Single file analysis
  #   analyzer = ImageQualityAnalyzer.new
  #   result = analyzer.analyze('image.svg')
  #
  #   puts result.quality_score.value   # => 85
  #   puts result.quality_score.good?   # => true
  #   puts result.clean?                # => false
  #
  #   puts result.to_report.render      # Terminal colored output
  #
  # @example Batch analysis
  #   analyzer = ImageQualityAnalyzer.new
  #   batch = analyzer.analyze_batch('./svgs')
  #   puts batch.render                 # Summary chart
  #
  # @example Programmatic summary
  #   analyzer = ImageQualityAnalyzer.new
  #   batch = analyzer.analyze_batch('./svgs')
  #
  #   puts "Average quality: #{batch.avg_quality_score.round(1)}"
  #   puts "Total errors: #{batch.total_errors}"
  #
  class ImageQualityAnalyzer
    # @param config [QualityMetrics::Configuration, nil]
    #   Configuration to use. Defaults to Configuration.default if nil.
    def initialize(config: nil)
      @config = config || QualityMetrics::Configuration.default
      @validator = Validator.new
      @error_analyzer = QualityMetrics::ErrorAnalyzer.new(@config)
      @feature_detector = QualityMetrics::FeatureDetector.new(@config)
      @complexity_calculator = QualityMetrics::ComplexityCalculator.new(@config)
      @quality_calculator = QualityMetrics::QualityCalculator.new(@config)
      @formatter = QualityMetrics::QualityReportFormatter.new
    end

    # Analyze a single SVG file.
    #
    # @param path [String] Path to SVG file
    # @param profile [Symbol, String] Profile name for validation
    # @return [QualityMetrics::QualityResult] Immutable result object
    #
    # @example
    #   result = analyzer.analyze('image.svg', profile: :svg_1_2_rfc)
    #   puts result.quality_score.grade  # => "B"
    #
    def analyze(path, profile: :svg_1_2_rfc)
      raise ArgumentError, "File not found: #{path}" unless File.exist?(path)

      file_size_bytes = File.size(path)
      content = File.read(path)

      # Run validation
      validation_result = @validator.validate(content, profile: profile)

      # Analyze errors
      error_breakdown = @error_analyzer.analyze(validation_result)

      # Detect features from content
      feature_flags = @feature_detector.detect(content)

      # Calculate complexity
      complexity_metrics = @complexity_calculator.calculate_from_content(
        content: content,
        features: feature_flags,
      )

      # Calculate all quality metrics
      @quality_calculator.calculate_all(
        validation_result: validation_result,
        file_path: path,
        file_size_bytes: file_size_bytes,
        error_breakdown: error_breakdown,
        complexity_metrics: complexity_metrics,
        feature_flags: feature_flags,
      )
    end

    # Analyze a single SVG file and return report for terminal output.
    #
    # @param path [String] Path to SVG file
    # @param profile [Symbol, String] Profile name for validation
    # @return [SvgQualityReport] Report with render method
    def analyze_report(path, profile: :svg_1_2_rfc)
      analyze(path, profile: profile).to_report
    end

    # Analyze all SVG files in a directory.
    #
    # @param dir [String] Directory path
    # @param pattern [String] Glob pattern for matching files
    # @param profile [Symbol, String] Profile name for validation
    # @param progress [Boolean] Show progress output
    # @return [SvgQualityBatchReport] Batch report with render method
    #
    # @example
    #   batch = analyzer.analyze_batch('./svgs', progress: true)
    #   puts batch.to_yaml  # Full YAML with all reports
    #   puts batch.render   # Summary chart with colors
    #
    def analyze_batch(dir, pattern: "**/*.svg", profile: :svg_1_2_rfc,
                      progress: false)
      reports = analyze_reports(dir, pattern: pattern, profile: profile,
                                     progress: progress)
      summary = summarize_reports(reports)

      SvgQualityBatchReport.new(
        total_files: summary[:total_files],
        successful: summary[:successful],
        failed: summary[:failed],
        avg_quality_score: summary[:avg_quality_score],
        quality_distribution: summary[:quality_distribution],
        avg_error_count: summary[:avg_error_count],
        total_errors: summary[:total_errors],
        remediable_errors: summary[:remediable_errors],
        non_remediable_errors: summary[:non_remediable_errors],
        reports: reports,
      )
    end

    # Analyze all SVG files and return array of reports.
    #
    # @param dir [String] Directory path
    # @param pattern [String] Glob pattern
    # @param profile [Symbol, String] Profile name
    # @param progress [Boolean] Show progress
    # @return [Array<SvgQualityReport>]
    def analyze_reports(dir, pattern: "**/*.svg", profile: :svg_1_2_rfc,
                        progress: false)
      files = glob_files(dir, pattern)
      reports = files.map { |file| analyze_report(file, profile: profile) }
      puts "Processed #{files.size} files..." if progress && !files.empty?
      reports
    rescue StandardError
      []
    end

    # Generate a formatted report from results.
    #
    # @param results [Array<SvgQualityReport>]
    # @param format [Symbol] :csv or :json
    # @return [String]
    def generate_report(results, format: :csv)
      case format
      when :csv then @formatter.format_csv(results)
      when :json then @formatter.format_json(results)
      else raise ArgumentError, "Unknown format: #{format}. Use :csv or :json"
      end
    end

    private

    def glob_files(dir, pattern)
      Dir.glob(File.join(dir, pattern))
    end

    def summarize_reports(reports)
      valid_reports = reports.select(&:file_path)

      {
        total_files: reports.size,
        successful: valid_reports.size,
        failed: reports.size - valid_reports.size,
        avg_quality_score: average_quality_score(valid_reports),
        quality_distribution: quality_distribution(valid_reports),
        avg_error_count: average_error_count(valid_reports),
        total_errors: total_errors(valid_reports),
        remediable_errors: total_remediable_errors(valid_reports),
        non_remediable_errors: total_non_remediable_errors(valid_reports),
      }
    end

    def average_quality_score(reports)
      return 0 if reports.empty?

      reports.sum(&:quality_score).to_f / reports.size
    end

    def average_error_count(reports)
      return 0 if reports.empty?

      reports.sum(&:error_count).to_f / reports.size
    end

    def total_errors(reports)
      reports.sum(&:error_count)
    end

    def total_remediable_errors(reports)
      reports.sum(&:remediable_errors)
    end

    def total_non_remediable_errors(reports)
      reports.sum(&:non_remediable_errors)
    end

    def quality_distribution(reports)
      distribution = Hash.new(0)
      reports.each do |r|
        distribution[r.quality_level.to_s] += 1
      end
      distribution
    end
  end
end
