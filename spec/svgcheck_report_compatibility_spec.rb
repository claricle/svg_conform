# frozen_string_literal: true

require 'spec_helper'
require 'svg_conform'

RSpec.describe 'SvgCheck Report Compatibility' do
  let(:input_dir) { File.join(__dir__, 'fixtures', 'svgcheck', 'inputs') }
  let(:check_dir) { File.join(__dir__, 'fixtures', 'svgcheck', 'check') }

  describe 'IETF profile validation against svgcheck outputs' do
    # Get all svgcheck output files
    Dir.glob(File.join(__dir__, 'fixtures', 'svgcheck', 'check', '*.out')).each do |out_file|
      basename = File.basename(out_file, '.svg.out')

      context basename.to_s do
        let(:input_file) { File.join(input_dir, "#{basename}.svg") }
        let(:svgcheck_out_file) { out_file }

        it 'produces compatible validation results' do
          skip 'Input file not found' unless File.exist?(input_file)

          # Parse svgcheck output
          svgcheck_content = File.read(svgcheck_out_file)
          parser = SvgConform::ExternalCheckers::Svgcheck::Parser.new
          svgcheck_report = parser.parse(svgcheck_content, nil, filename: "#{basename}.svg")

          # Run SvgConform validation
          validator = SvgConform::Validator.new(profile: 'svg_1_2_rfc')
          result = validator.validate_file(input_file)

          # Create SvgConform report with svgcheck mapping
          svg_conform_report = SvgConform::ConformanceReport.from_svg_conform_result(
            "#{basename}.svg",
            result,
            profile: 'svg_1_2_rfc',
            use_svgcheck_mapping: true
          )

          # Compare error counts (100% compatibility achieved!)
          expect(svg_conform_report.errors.total_count).to eq(svgcheck_report.errors.total_count),
            "Error count mismatch for #{basename}: SvgConform=#{svg_conform_report.errors.total_count}, svgcheck=#{svgcheck_report.errors.total_count}"

          # Compare error types/requirements
          svg_conform_reqs = svg_conform_report.errors.by_requirement.keys.sort
          svgcheck_reqs = svgcheck_report.errors.by_requirement.keys.sort

          expect(svg_conform_reqs).to match_array(svgcheck_reqs),
            "Error requirement types mismatch for #{basename}: SvgConform=#{svg_conform_reqs}, svgcheck=#{svgcheck_reqs}"

          # Compare error counts by requirement
          svgcheck_reqs.each do |req_id|
            svg_conform_count = svg_conform_report.errors.by_requirement[req_id] || 0
            svgcheck_count = svgcheck_report.errors.by_requirement[req_id] || 0

            expect(svg_conform_count).to eq(svgcheck_count),
              "Error count for #{req_id} in #{basename} mismatch: SvgConform=#{svg_conform_count}, svgcheck=#{svgcheck_count}"
          end
        end

        it 'handles the same file without crashing' do
          skip 'Input file not found' unless File.exist?(input_file)

          # Test that we can parse and validate the same files svgcheck can handle
          expect do
            validator = SvgConform::Validator.new(profile: 'svg_1_2_rfc')
            validator.validate_file(input_file)
          end.not_to raise_error, "SvgConform should handle #{basename} without crashing"
        end
      end
    end
  end

  describe 'Report format compatibility' do
    it 'generates reports with proper structure' do
      input_file = File.join(input_dir, 'circle.svg')
      skip 'Input file not found' unless File.exist?(input_file)

      # Generate SvgConform report
      validator = SvgConform::Validator.new(profile: 'svg_1_2_rfc')
      result = validator.validate_file(input_file)

      svg_conform_report = SvgConform::ConformanceReport.from_svg_conform_result(
        'circle.svg', result, profile: 'svg_1_2_rfc'
      )

      # Verify report structure
      expect(svg_conform_report.respond_to?(:filename)).to be true
      expect(svg_conform_report.respond_to?(:tool)).to be true
      expect(svg_conform_report.respond_to?(:valid)).to be true
      expect(svg_conform_report.respond_to?(:errors)).to be true
      expect(svg_conform_report.respond_to?(:warnings)).to be true

      # Error structure
      expect(svg_conform_report.errors.respond_to?(:total_count)).to be true
      expect(svg_conform_report.errors.respond_to?(:by_requirement)).to be true
      expect(svg_conform_report.errors.respond_to?(:issues)).to be true
    end
  end

  describe 'Summary statistics' do
    it 'achieves 100% compatibility with svgcheck' do
      total_files = 0
      identical_files = 0

      Dir.glob(File.join(check_dir, '*.out')).each do |out_file|
        basename = File.basename(out_file, '.svg.out')
        input_file = File.join(input_dir, "#{basename}.svg")
        next unless File.exist?(input_file)

        total_files += 1

        begin
          # Parse svgcheck output
          svgcheck_content = File.read(out_file)
          parser = SvgConform::ExternalCheckers::Svgcheck::Parser.new
          svgcheck_report = parser.parse(svgcheck_content, nil, filename: "#{basename}.svg")

          # Run SvgConform validation
          validator = SvgConform::Validator.new(profile: 'svg_1_2_rfc')
          result = validator.validate_file(input_file)
          svg_conform_report = SvgConform::ConformanceReport.from_svg_conform_result(
            "#{basename}.svg",
            result,
            profile: 'svg_1_2_rfc',
            use_svgcheck_mapping: true
          )

          # Check if error counts match
          if svg_conform_report.errors.total_count == svgcheck_report.errors.total_count
            identical_files += 1
          end
        rescue StandardError => e
          puts "Error processing #{basename}: #{e.message}"
        end
      end

      puts "\n#{'=' * 60}"
      puts 'SVGCHECK COMPATIBILITY SUMMARY'
      puts '=' * 60
      puts "Total files processed: #{total_files}"
      puts "Identical error counts: #{identical_files}/#{total_files}"
      puts "Compatibility: #{(identical_files.to_f / total_files * 100).round(1)}%" if total_files > 0
      puts '=' * 60

      # We've achieved 100% compatibility!
      if total_files > 0
        compatibility_pct = identical_files.to_f / total_files
        expect(compatibility_pct).to eq(1.0),
          "Expected 100% compatibility but got #{(compatibility_pct * 100).round(1)}%"
      else
        skip 'No svgcheck output files found to compare against'
      end
    end
  end
end
