# frozen_string_literal: true

require 'spec_helper'
require 'svg_conform'

RSpec.describe 'SvgCheck Report Compatibility' do
  let(:input_dir) { File.join(__dir__, '..', 'svgcheck', 'svgcheck', 'Tests') }
  let(:reports_dir) { File.join(__dir__, 'fixtures', 'svgcheck_reports') }

  describe 'IETF profile validation against svgcheck reports' do
    # Get all generated svgcheck reports (excluding full-tiny.xml which is too large)
    Dir.glob(File.join(__dir__, 'fixtures', 'svgcheck_reports', '*.yaml')).each do |report_file|
      basename = File.basename(report_file, '.svgcheck.yaml')
      next if basename == 'full-tiny.xml' # Skip the problematic file

      context basename.to_s do
        let(:input_file) { File.join(input_dir, basename) }
        let(:svgcheck_report) { SvgConform::ConformanceReport.load_from_file(report_file) }

        it 'produces compatible validation results' do
          skip 'Input file not found' unless File.exist?(input_file)

          # Run SvgConform validation
          svg_content = File.read(input_file)
          validator = SvgConform::Validator.new
          result = validator.validate(svg_content, profile: :svg_1_2_rfc)

          # Create SvgConform report with svgcheck mapping
          svg_conform_report = SvgConform::ConformanceReport.from_svg_conform_result(
            basename, result, profile: 'svg_1_2_rfc', use_svgcheck_mapping: true
          )

          # Compare validation status
          expect(svg_conform_report.valid).to eq(svgcheck_report.valid),
                                              "Validation status mismatch: SvgConform=#{svg_conform_report.valid}, svgcheck=#{svgcheck_report.valid}"

          # Compare error counts
          expect(svg_conform_report.errors.total_count).to eq(svgcheck_report.errors.total_count),
                                                           "Error count mismatch: SvgConform=#{svg_conform_report.errors.total_count}, svgcheck=#{svgcheck_report.errors.total_count}"

          # Compare warning counts
          expect(svg_conform_report.warnings.total_count).to eq(svgcheck_report.warnings.total_count),
                                                             "Warning count mismatch: SvgConform=#{svg_conform_report.warnings.total_count}, svgcheck=#{svgcheck_report.warnings.total_count}"

          # Compare error types/requirements
          svg_conform_reqs = svg_conform_report.errors.by_requirement.keys.sort
          svgcheck_reqs = svgcheck_report.errors.by_requirement.keys.sort

          expect(svg_conform_reqs).to match_array(svgcheck_reqs),
                                      "Error requirement types mismatch: SvgConform=#{svg_conform_reqs}, svgcheck=#{svgcheck_reqs}"

          # Compare error counts by requirement
          svgcheck_reqs.each do |req_id|
            svg_conform_count = svg_conform_report.errors.by_requirement[req_id] || 0
            svgcheck_count = svgcheck_report.errors.by_requirement[req_id] || 0

            expect(svg_conform_count).to eq(svgcheck_count),
                                         "Error count for #{req_id} mismatch: SvgConform=#{svg_conform_count}, svgcheck=#{svgcheck_count}"
          end
        end

        it 'produces similar error messages' do
          skip 'Input file not found' unless File.exist?(input_file)
          skip 'No errors in svgcheck report' if svgcheck_report.errors.total_count == 0

          # Run SvgConform validation
          svg_content = File.read(input_file)
          validator = SvgConform::Validator.new
          result = validator.validate(svg_content, profile: :svg_1_2_rfc)

          # Create SvgConform report with svgcheck mapping
          svg_conform_report = SvgConform::ConformanceReport.from_svg_conform_result(
            basename, result, profile: 'svg_1_2_rfc', use_svgcheck_mapping: true
          )

          # Compare individual error details
          svg_conform_errors = svg_conform_report.errors.issues
          svgcheck_errors = svgcheck_report.errors.issues

          expect(svg_conform_errors.length).to eq(svgcheck_errors.length),
                                               "Number of individual errors mismatch: SvgConform=#{svg_conform_errors.length}, svgcheck=#{svgcheck_errors.length}"

          # Group errors by requirement for comparison
          svg_conform_by_req = svg_conform_errors.group_by(&:requirement_id)
          svgcheck_by_req = svgcheck_errors.group_by(&:requirement_id)

          svgcheck_by_req.each do |req_id, svgcheck_req_errors|
            svg_conform_req_errors = svg_conform_by_req[req_id] || []

            expect(svg_conform_req_errors.length).to eq(svgcheck_req_errors.length),
                                                     "Error count for #{req_id} mismatch: SvgConform=#{svg_conform_req_errors.length}, svgcheck=#{svgcheck_req_errors.length}"

            # Check that error types match
            svg_conform_req_errors.each do |error|
              expect(error.requirement_id).to eq(req_id),
                                              "Error requirement_id mismatch for #{req_id}"
            end
          end
        end

        it 'handles the same file without crashing' do
          skip 'Input file not found' unless File.exist?(input_file)

          # Test that we can at least parse and validate the same files svgcheck can handle
          expect do
            svg_content = File.read(input_file)
            validator = SvgConform::Validator.new
            validator.validate(svg_content, profile: :svg_1_2_rfc)
          end.not_to raise_error, "SvgConform should handle #{basename} without crashing"
        end
      end
    end
  end

  describe 'Report format compatibility' do
    let(:sample_report_file) { File.join(reports_dir, 'circle.svg.svgcheck.yaml') }

    it 'can load svgcheck reports' do
      skip 'Sample report not found' unless File.exist?(sample_report_file)

      expect do
        SvgConform::ConformanceReport.load_from_file(sample_report_file)
      end.not_to raise_error, 'Should be able to load svgcheck reports'

      report = SvgConform::ConformanceReport.load_from_file(sample_report_file)
      expect(report.tool).to eq('svgcheck')
      expect(report.filename).to eq('circle.svg')
      expect(report.version).to include('svgcheck')
    end

    it 'generates reports in the same format' do
      skip 'Sample report not found' unless File.exist?(sample_report_file)

      input_file = File.join(input_dir, 'circle.svg')
      skip 'Input file not found' unless File.exist?(input_file)

      # Generate SvgConform report
      svg_content = File.read(input_file)
      validator = SvgConform::Validator.new
      result = validator.validate(svg_content, profile: :svg_1_2_rfc)

      svg_conform_report = SvgConform::ConformanceReport.from_svg_conform_result(
        'circle.svg', result, profile: 'svg_1_2_rfc'
      )

      # Load svgcheck report
      SvgConform::ConformanceReport.load_from_file(sample_report_file)

      # Both should have the same structure
      expect(svg_conform_report.respond_to?(:filename)).to be true
      expect(svg_conform_report.respond_to?(:tool)).to be true
      expect(svg_conform_report.respond_to?(:version)).to be true
      expect(svg_conform_report.respond_to?(:valid)).to be true
      expect(svg_conform_report.respond_to?(:errors)).to be true
      expect(svg_conform_report.respond_to?(:warnings)).to be true

      # Error structure should match
      expect(svg_conform_report.errors.respond_to?(:total_count)).to be true
      expect(svg_conform_report.errors.respond_to?(:by_requirement)).to be true
      expect(svg_conform_report.errors.respond_to?(:issues)).to be true
    end
  end

  describe 'Summary statistics' do
    it 'provides overall compatibility summary' do
      total_files = 0
      matching_files = 0
      error_count_matches = 0
      validation_status_matches = 0

      Dir.glob(File.join(reports_dir, '*.yaml')).each do |report_file|
        basename = File.basename(report_file, '.svgcheck.yaml')
        next if basename == 'full-tiny.xml' # Skip problematic file

        input_file = File.join(input_dir, basename)
        next unless File.exist?(input_file)

        total_files += 1

        begin
          # Load svgcheck report
          svgcheck_report = SvgConform::ConformanceReport.load_from_file(report_file)

          # Run SvgConform validation
          svg_content = File.read(input_file)
          validator = SvgConform::Validator.new
          result = validator.validate(svg_content, profile: :svg_1_2_rfc)

          svg_conform_report = SvgConform::ConformanceReport.from_svg_conform_result(
            basename, result, profile: 'svg_1_2_rfc', use_svgcheck_mapping: true
          )

          matching_files += 1

          # Check validation status match
          validation_status_matches += 1 if svg_conform_report.valid == svgcheck_report.valid

          # Check error count match
          error_count_matches += 1 if svg_conform_report.errors.total_count == svgcheck_report.errors.total_count
        rescue StandardError => e
          puts "Error processing #{basename}: #{e.message}"
        end
      end

      puts "\n#{'=' * 60}"
      puts 'SVGCHECK COMPATIBILITY SUMMARY'
      puts '=' * 60
      puts "Total files processed: #{total_files}"
      puts "Successfully compared: #{matching_files}"
      puts "Validation status matches: #{validation_status_matches}/#{matching_files} (#{(validation_status_matches.to_f / matching_files * 100).round(1)}%)"
      puts "Error count matches: #{error_count_matches}/#{matching_files} (#{(error_count_matches.to_f / matching_files * 100).round(1)}%)"
      puts '=' * 60

      # We expect at least some level of compatibility
      if matching_files > 0
        expect(validation_status_matches.to_f / matching_files).to be >= 0.5,
                                                                   'Should have at least 50% validation status compatibility'
      else
        skip 'No svgcheck report files found to compare against'
      end
    end
  end
end
