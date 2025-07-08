# frozen_string_literal: true

require 'fileutils'

namespace :fixtures do
  desc 'Generate YAML conformance reports for all test fixtures'
  task :generate_reports do
    puts 'Generating YAML conformance reports for all test fixtures...'

    require_relative '../svg_conform'

    # Create reports directory
    reports_dir = 'spec/fixtures/reports'
    FileUtils.mkdir_p(reports_dir)

    # Get all test files
    input_dir = 'spec/fixtures/svgcheck/inputs'
    test_files = Dir.glob("#{input_dir}/*.{svg,xml}").map { |f| File.basename(f) }

    puts "Found #{test_files.length} test files to process..."

    success_count = 0
    error_count = 0

    test_files.each do |filename|
      puts "Processing #{filename}..."

      # Read the input file
      input_path = "#{input_dir}/#{filename}"

      # Read expected error output if it exists
      error_file = filename.sub(/\.(svg|xml)$/, '.err')
      error_path = "spec/fixtures/svgcheck/expected_dynamic/#{error_file}"

      error_content = ''
      error_content = File.read(error_path) if File.exist?(error_path)

      # Generate svgcheck report
      svgcheck_report = SvgConform::ConformanceReport.from_svgcheck_result(
        filename,
        error_content
      )

      # Save svgcheck report
      svgcheck_yaml_path = "#{reports_dir}/#{filename}.svgcheck.yml"
      svgcheck_report.save_to_file(svgcheck_yaml_path)

      # Generate svg_conform report
      begin
        # Load and validate with svg_conform using the convenience method
        validation_result = SvgConform.validate_file(input_path, profile: :svg_1_2_rfc)

        svg_conform_report = SvgConform::ConformanceReport.from_svg_conform_result(
          filename,
          validation_result,
          profile: 'svg_1_2_rfc'
        )

        # Save svg_conform report
        svg_conform_yaml_path = "#{reports_dir}/#{filename}.svg_conform.yml"
        svg_conform_report.save_to_file(svg_conform_yaml_path)

        puts "  ✅ Generated both reports for #{filename}"
        success_count += 1
      rescue StandardError => e
        puts "  ❌ Error generating svg_conform report for #{filename}: #{e.message}"

        # Still save a minimal svg_conform report
        error_report = SvgConform::ConformanceReport.new
        error_report.filename = filename
        error_report.tool = 'svg_conform'
        error_report.version = SvgConform::VERSION
        error_report.timestamp = Time.now.iso8601
        error_report.valid = false
        error_report.errors = SvgConform::IssueSummary.new
        error_report.errors.total_count = 1
        error_report.errors.by_requirement = { 'parse_error' => 1 }
        error_report.errors.sample_issues = [
          SvgConform::ConformanceIssue.new(
            type: 'error',
            requirement_id: 'parse_error',
            message: e.message,
            element: 'document',
            line: 1
          )
        ]
        error_report.warnings = SvgConform::IssueSummary.new
        error_report.warnings.total_count = 0
        error_report.warnings.by_requirement = {}
        error_report.warnings.sample_issues = []

        svg_conform_yaml_path = "#{reports_dir}/#{filename}.svg_conform.yml"
        error_report.save_to_file(svg_conform_yaml_path)

        puts "  ⚠️  Generated error report for #{filename}"
        error_count += 1
      end
    end

    puts "\n#{'=' * 60}"
    puts 'FIXTURE REPORT GENERATION SUMMARY'
    puts '=' * 60
    puts "Total files processed: #{test_files.length}"
    puts "Successful reports: #{success_count}"
    puts "Error reports: #{error_count}"
    puts "Reports saved to: #{reports_dir}/"

    # List generated files
    puts "\nGenerated files:"
    Dir.glob("#{reports_dir}/*").sort.each { |f| puts "  - #{File.basename(f)}" }

    puts "\n✅ Fixture report generation complete!"
  end

  desc 'Validate all fixture reports can be loaded'
  task :validate_reports do
    puts 'Validating all fixture reports can be loaded...'

    require_relative '../svg_conform'

    reports_dir = 'spec/fixtures/reports'
    unless Dir.exist?(reports_dir)
      puts "❌ Reports directory not found. Run 'rake fixtures:generate_reports' first."
      exit 1
    end

    report_files = Dir.glob("#{reports_dir}/*.yml")
    if report_files.empty?
      puts "❌ No report files found. Run 'rake fixtures:generate_reports' first."
      exit 1
    end

    puts "Found #{report_files.length} report files to validate..."

    success_count = 0
    error_count = 0

    report_files.each do |report_file|
      filename = File.basename(report_file)
      print "Validating #{filename}... "

      begin
        report = SvgConform::ConformanceReport.load_from_file(report_file)

        # Basic validation
        raise 'Missing filename' unless report.filename
        raise 'Missing tool' unless report.tool
        raise 'Missing timestamp' unless report.timestamp
        raise 'Missing errors summary' unless report.errors
        raise 'Missing warnings summary' unless report.warnings

        puts '✅'
        success_count += 1
      rescue StandardError => e
        puts "❌ #{e.message}"
        error_count += 1
      end
    end

    puts "\n#{'=' * 60}"
    puts 'FIXTURE REPORT VALIDATION SUMMARY'
    puts '=' * 60
    puts "Total reports: #{report_files.length}"
    puts "Valid reports: #{success_count}"
    puts "Invalid reports: #{error_count}"

    if error_count.positive?
      puts "\n❌ Some reports failed validation!"
      exit 1
    else
      puts "\n✅ All reports are valid!"
    end
  end

  desc 'Compare fixture reports between tools'
  task :compare_reports do
    puts 'Comparing fixture reports between svg_conform and svgcheck...'

    require_relative '../svg_conform'

    reports_dir = 'spec/fixtures/reports'
    unless Dir.exist?(reports_dir)
      puts "❌ Reports directory not found. Run 'rake fixtures:generate_reports' first."
      exit 1
    end

    # Get all base filenames (without tool suffix)
    base_files = Dir.glob("#{reports_dir}/*.svg_conform.yml").map do |f|
      File.basename(f, '.svg_conform.yml')
    end

    puts "Found #{base_files.length} test cases to compare..."

    identical_count = 0
    different_count = 0
    differences = []

    base_files.each do |base_filename|
      svg_conform_path = "#{reports_dir}/#{base_filename}.svg_conform.yml"
      svgcheck_path = "#{reports_dir}/#{base_filename}.svgcheck.yml"

      next unless File.exist?(svg_conform_path) && File.exist?(svgcheck_path)

      puts "Comparing #{base_filename}..."

      begin
        svg_conform_report = SvgConform::ConformanceReport.load_from_file(svg_conform_path)
        svgcheck_report = SvgConform::ConformanceReport.load_from_file(svgcheck_path)

        comparison = svg_conform_report.compare_with(svgcheck_report)

        if comparison[:identical]
          puts '  ✅ Reports are identical'
          identical_count += 1
        else
          puts '  ❌ Reports differ:'
          comparison[:differences].each { |diff| puts "    - #{diff}" }
          different_count += 1
          differences << {
            file: base_filename,
            differences: comparison[:differences]
          }
        end
      rescue StandardError => e
        puts "  ❌ Error comparing reports: #{e.message}"
        different_count += 1
        differences << {
          file: base_filename,
          differences: ["Comparison error: #{e.message}"]
        }
      end
    end

    puts "\n#{'=' * 60}"
    puts 'FIXTURE REPORT COMPARISON SUMMARY'
    puts '=' * 60
    puts "Total comparisons: #{base_files.length}"
    puts "Identical reports: #{identical_count}"
    puts "Different reports: #{different_count}"
    puts "Compatibility rate: #{((identical_count.to_f / base_files.length) * 100).round(1)}%"

    if differences.any?
      puts "\nFiles with differences:"
      differences.each do |diff|
        puts "  - #{diff[:file]}:"
        diff[:differences].each { |d| puts "    #{d}" }
      end
    end

    puts "\n#{different_count.positive? ? '❌' : '✅'} Comparison complete!"
  end

  desc 'Clean all generated fixture reports'
  task :clean_reports do
    puts 'Cleaning all generated fixture reports...'

    reports_dir = 'spec/fixtures/reports'
    if Dir.exist?(reports_dir)
      FileUtils.rm_rf(reports_dir)
      puts "✅ Cleaned #{reports_dir}/"
    else
      puts "⚠️  Reports directory doesn't exist"
    end
  end

  desc 'Regenerate all fixture reports (clean + generate)'
  task regenerate_reports: %i[clean_reports generate_reports]

  desc 'Full fixture workflow (generate + validate + compare)'
  task all: %i[generate_reports validate_reports compare_reports]

  desc 'Show fixture report statistics'
  task :stats do
    puts 'Fixture Report Statistics'
    puts '=' * 40

    require_relative '../svg_conform'

    reports_dir = 'spec/fixtures/reports'
    unless Dir.exist?(reports_dir)
      puts "❌ Reports directory not found. Run 'rake fixtures:generate_reports' first."
      exit 1
    end

    svg_conform_reports = Dir.glob("#{reports_dir}/*.svg_conform.yml")
    svgcheck_reports = Dir.glob("#{reports_dir}/*.svgcheck.yml")

    puts "Total svg_conform reports: #{svg_conform_reports.length}"
    puts "Total svgcheck reports: #{svgcheck_reports.length}"

    # Analyze error counts
    total_svg_conform_errors = 0
    total_svgcheck_errors = 0

    svg_conform_reports.each do |report_file|
      report = SvgConform::ConformanceReport.load_from_file(report_file)
      total_svg_conform_errors += report.errors.total_count
    rescue StandardError
      # Skip invalid reports
    end

    svgcheck_reports.each do |report_file|
      report = SvgConform::ConformanceReport.load_from_file(report_file)
      total_svgcheck_errors += report.errors.total_count
    rescue StandardError
      # Skip invalid reports
    end

    puts "Total svg_conform errors: #{total_svg_conform_errors}"
    puts "Total svgcheck errors: #{total_svgcheck_errors}"
    puts "Average errors per file (svg_conform): #{(total_svg_conform_errors.to_f / svg_conform_reports.length).round(2)}"
    puts "Average errors per file (svgcheck): #{(total_svgcheck_errors.to_f / svgcheck_reports.length).round(2)}"

    puts "\n✅ Statistics complete!"
  end
end
