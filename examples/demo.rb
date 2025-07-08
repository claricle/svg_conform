#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script showing SvgConform capabilities
require_relative '../lib/svg_conform'

puts 'SvgConform Demo'
puts '=' * 50

# Test with actual fixture files
fixtures_dir = File.join(__dir__, '..', 'spec', 'fixtures', 'svgcheck', 'inputs')
test_files = ['viewBox-height.svg', 'colors.svg', 'IETF-test.svg', 'good.svg']

validator = SvgConform::Validator.new

# Show available profiles
puts "\n1. Available Profiles:"
puts '-' * 30

SvgConform::Profiles.available_profiles.each do |name|
  profile = SvgConform::Profiles.get(name)
  puts "#{name}: #{profile.description} (#{profile.requirement_count} requirements, #{profile.remediation_count} remediations)"
end

# Test each profile with sample files
test_files.each do |filename|
  file_path = File.join(fixtures_dir, filename)
  next unless File.exist?(file_path)

  puts "\n#{'=' * 60}"
  puts "Testing file: #{filename}"
  puts '=' * 60

  # Read and display the SVG content
  svg_content = File.read(file_path)
  puts "\nSVG Content:"
  puts svg_content
  puts

  # Test each profile
  SvgConform::Profiles.available_profiles.each do |profile_name|
    puts "\n#{profile_name.to_s.upcase} Profile Results:"
    puts '-' * 40

    begin
      result = validator.validate_file(file_path, profile: profile_name)

      puts "Status: #{result.valid? ? 'VALID ✓' : 'INVALID ✗'}"
      puts "Errors: #{result.error_count}"
      puts "Warnings: #{result.warning_count}"

      if result.has_errors?
        puts "\nErrors:"
        result.errors.each_with_index do |error, i|
          puts "  #{i + 1}. #{error.message} (#{error.requirement_id})"
        end
      end

      if result.has_warnings?
        puts "\nWarnings:"
        result.warnings.each_with_index do |warning, i|
          puts "  #{i + 1}. #{warning.message} (#{warning.requirement_id})"
        end
      end

      # Test remediation if available
      if result.fixable?
        puts "\nApplying fixes (#{result.fixable_count} available)..."

        # Apply fixes using the ValidationResult's built-in fix method
        result.apply_fixes

        if result.fixed?
          puts '✓ Fixes applied successfully!'
          puts 'Fixed SVG preview (first 200 chars):'
          fixed_content = result.fixed_document.to_xml
          puts fixed_content[0..200] + (fixed_content.length > 200 ? '...' : '')

          # Re-validate the fixed document
          fixed_result = validator.validate(fixed_content, profile: profile_name)
          puts "\nRe-validation: #{fixed_result.valid? ? 'VALID ✓' : 'INVALID ✗'}"
          puts "Remaining errors: #{fixed_result.error_count}"
        else
          puts '✗ Could not apply fixes'
        end
      end
    rescue StandardError => e
      puts "ERROR: #{e.message}"
    end
  end
end

# Performance test
puts "\n#{'=' * 60}"
puts 'Performance Test'
puts '=' * 60

require 'benchmark'
test_file = File.join(fixtures_dir, 'good.svg')

if File.exist?(test_file)
  time = Benchmark.realtime do
    100.times do
      validator.validate_file(test_file, profile: :svg_1_2_rfc)
    end
  end

  puts "Validated #{test_file} 100 times in #{time.round(3)} seconds"
  puts "Average: #{(time * 1000 / 100).round(2)}ms per validation"
else
  puts 'Performance test skipped - test file not found'
end

puts "\nDemo completed!"
