#!/usr/bin/env ruby
# frozen_string_literal: true

# Working example based on README.adoc Ruby API usage section
require_relative "../lib/svg_conform"

puts "=" * 60
puts "README Ruby API Usage Example"
puts "=" * 60
puts

# Sample SVG content with some issues
svg_content = <<~SVG
  <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
    <rect fill="red" width="50" height="50"/>
    <circle fill="blue" cx="75" cy="75" r="20"/>
  </svg>
SVG

puts "Test SVG content:"
puts svg_content
puts

# Load a profile and validate
profile = SvgConform::Profiles.get(:svg_1_2_rfc)
document = SvgConform::Document.new(svg_content)
result = profile.validate(document)

puts "Validation Results:"
puts "Valid: #{result.valid?}"
puts "Errors: #{result.errors.count}"
puts "Warnings: #{result.warnings.count}"
puts

if result.errors.any?
  puts "Error details:"
  result.errors.each_with_index do |error, i|
    puts "  #{i + 1}. [#{error.requirement_id}] #{error.message}"
  end
  puts
end

# Apply remediations to fix issues
if !result.valid? && profile.remediation_count > 0
  puts "Applying remediations (profile has #{profile.remediation_count} remediations)..."
  changes = profile.apply_remediations(document)

  puts "Applied #{changes.length} remediations"
  puts

  puts "Fixed SVG:"
  puts document.to_xml
  puts

  # Re-validate to confirm fixes
  result_after = profile.validate(document)
  puts "Re-validation after fixes:"
  puts "Valid: #{result_after.valid?}"
  puts "Errors: #{result_after.errors.count}"
else
  puts "Document is already valid or no remediations available"
end

puts
puts "=" * 60
puts "Example complete!"
puts "=" * 60
