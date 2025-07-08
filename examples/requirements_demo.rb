#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/svg_conform'

# Demo script showing the new requirements and remediations system
class RequirementsDemo
  def run
    puts '=== SvgConform Requirements & Remediations Demo ==='
    puts

    # Demo 1: Load profile from YAML
    demo_yaml_profile_loading

    # Demo 2: Validate with requirements
    demo_requirements_validation

    # Demo 3: Apply remediations
    demo_remediations

    # Demo 4: Lucid fix scenario
    demo_lucid_fix
  end

  private

  def demo_yaml_profile_loading
    puts '1. Loading Profiles from YAML Configuration'
    puts '=' * 50

    begin
      # Load IETF profile from YAML
      svg_1_2_rfc_profile = SvgConform::ProfileRegistry.load_profile('svg_1_2_rfc')
      puts "✓ Loaded IETF profile: #{svg_1_2_rfc_profile.name}"
      puts "  Description: #{svg_1_2_rfc_profile.description}"
      puts "  Requirements: #{svg_1_2_rfc_profile.requirement_count}"
      puts "  Remediations: #{svg_1_2_rfc_profile.remediation_count}"
      puts

      # Load Lucid fix profile
      lucid_profile = SvgConform::ProfileRegistry.load_profile('lucid_fix')
      puts "✓ Loaded Lucid Fix profile: #{lucid_profile.name}"
      puts "  Description: #{lucid_profile.description}"
      puts "  Requirements: #{lucid_profile.requirement_count}"
      puts "  Remediations: #{lucid_profile.remediation_count}"
      puts

      # List available profiles
      available = SvgConform::ProfileRegistry.available_profiles
      puts "Available profiles: #{available.join(', ')}"
      puts
    rescue StandardError => e
      puts "✗ Error loading profiles: #{e.message}"
      puts "  This is expected if the requirement classes don't exist yet"
      puts
    end
  end

  def demo_requirements_validation
    puts '2. Requirements-based Validation'
    puts '=' * 50

    # Create a test SVG with invalid use element
    invalid_svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
        <defs>
          <circle id="valid-circle" cx="10" cy="10" r="5"/>
        </defs>
        <use href="#invalid-id"/>
        <use href="#valid-circle"/>
        <rect fill="red" width="50" height="50"/>
      </svg>
    SVG

    puts 'Test SVG with invalid use element:'
    puts invalid_svg
    puts

    # Create a simple profile with requirements
    profile = SvgConform::Profile.new(:test_requirements, 'Test Requirements Profile')

    begin
      # Add invalid ID references requirement
      requirement = SvgConform::Requirements::InvalidIdReferencesRequirement.new
      profile.add_requirement(requirement)

      # Validate
      document = SvgConform::Document.new(invalid_svg)
      result = profile.validate(document)

      puts 'Validation Results:'
      puts "  Valid: #{result.valid?}"
      puts "  Errors: #{result.error_count}"
      puts "  Warnings: #{result.warning_count}"
      puts

      if result.errors.any?
        puts 'Errors found:'
        result.errors.each_with_index do |error, i|
          puts "  #{i + 1}. #{error.message}"
          puts "     Node: #{error.node.name}" if error.node
          puts "     Data: #{error.data}" if error.data.any?
        end
        puts
      end
    rescue StandardError => e
      puts "✗ Error during validation: #{e.message}"
      puts "  This is expected if the requirement classes don't exist yet"
      puts
    end
  end

  def demo_remediations
    puts '3. Applying Remediations'
    puts '=' * 50

    # Create test SVG with issues
    problematic_svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
        <defs>
          <circle id="circle1" cx="10" cy="10" r="5"/>
        </defs>
        <use href="#missing-id"/>
        <use href="#circle1"/>
        <use href="#another-missing"/>
      </svg>
    SVG

    puts 'Original SVG with invalid use elements:'
    puts problematic_svg
    puts

    begin
      # Create profile with requirements and remediations
      profile = SvgConform::Profile.new(:test_remediations, 'Test Remediations Profile')

      # Add requirement
      requirement = SvgConform::Requirements::InvalidIdReferencesRequirement.new
      profile.add_requirement(requirement)

      # Add remediation
      remediation = SvgConform::Remediations::InvalidIdReferencesRemediation.new
      profile.add_remediation(remediation)

      # Validate first
      document = SvgConform::Document.new(problematic_svg)
      result = profile.validate(document)

      puts "Validation found #{result.error_count} errors"

      if result.errors.any?
        # Debug: Show requirement IDs
        puts "Failed requirement IDs: #{result.failed_requirements.map(&:requirement_id)}"
        puts "Available remediations: #{profile.remediations.map { |r| "#{r.id} (targets: #{r.target_requirements})" }}"
        puts

        # Apply remediations
        engine = SvgConform::RemediationEngine.new(profile)
        remediation_results = engine.apply_remediations(document, result)

        puts "Applied #{remediation_results.size} remediations"
        puts "Summary: #{engine.summary}"
        puts

        puts 'Fixed SVG:'
        puts document.to_xml
        puts
      end
    rescue StandardError => e
      puts "✗ Error during remediation: #{e.message}"
      puts "  This is expected if the remediation classes don't exist yet"
      puts
    end
  end

  def demo_lucid_fix
    puts '4. Lucid SVG Fix Scenario'
    puts '=' * 50

    # Simulate a Lucid-generated SVG with invalid use elements
    lucid_svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 200 100">
        <defs>
          <g id="shape1">
            <rect width="20" height="20" fill="blue"/>
          </g>
        </defs>
        <g>
          <use xlink:href="#shape1" x="10" y="10"/>
          <use xlink:href="#nonexistent1" x="50" y="10"/>
          <use xlink:href="#nonexistent2" x="90" y="10"/>
          <text x="10" y="50">Valid content</text>
        </g>
      </svg>
    SVG

    puts 'Lucid-style SVG with invalid use elements:'
    puts lucid_svg
    puts

    begin
      # Load the Lucid fix profile
      profile = SvgConform::ProfileRegistry.load_profile('lucid_fix')

      # Process the SVG
      document = SvgConform::Document.new(lucid_svg)
      result = profile.validate(document)

      puts "Found #{result.error_count} invalid use elements"

      if result.errors.any?
        # Apply the Lucid fix
        engine = SvgConform::RemediationEngine.new(profile)
        engine.apply_remediations(document, result)

        puts 'Applied Lucid fix remediations'
        puts "Summary: #{engine.summary}"
        puts

        puts 'Fixed SVG (invalid use elements removed):'
        puts document.to_xml
        puts
      end
    rescue StandardError => e
      puts "✗ Error during Lucid fix: #{e.message}"
      puts "  This is expected if the profile/classes don't exist yet"
      puts
    end
  end
end

# Run the demo
if __FILE__ == $PROGRAM_NAME
  demo = RequirementsDemo.new
  demo.run
end
