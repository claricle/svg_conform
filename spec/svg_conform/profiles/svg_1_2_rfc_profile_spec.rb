# frozen_string_literal: true

require "spec_helper"
require "canon"
require "tempfile"

RSpec.describe "SVG 1.2 RFC Profile" do
  let(:svg_1_2_rfc_profile_path) { "config/profiles/svg_1_2_rfc.yml" }
  let(:fixtures_base_dir) { "spec/fixtures" }

  describe "profile loading" do
    it "loads the SVG 1.2 RFC profile successfully" do
      profile = SvgConform::Profile.load_from_file(svg_1_2_rfc_profile_path)
      expect(profile).not_to be_nil
      expect(profile.name).to eq("svg_1_2_rfc")
      expect(profile.description).to include("RFC 7996")
    end

    it "has all expected requirements" do
      profile = SvgConform::Profile.load_from_file(svg_1_2_rfc_profile_path)
      requirement_ids = profile.requirements.map(&:id)

      expected_requirements = %w[
        allowed_elements
        color_restrictions
        font_family
        style
        namespace_validation
        namespace_attributes
        viewbox_required
        link_validation
        id_references
        forbidden_content
        style_promotion
      ]

      expect(requirement_ids).to include(*expected_requirements)
    end

    it "has all expected remediations" do
      profile = SvgConform::Profile.load_from_file(svg_1_2_rfc_profile_path)
      remediation_ids = profile.remediations.map(&:id)

      expected_remediations = %w[
        color_conversion
        font_family_conversion
        style_promotion
        viewbox_generation
      ]

      expect(remediation_ids).to include(*expected_remediations)
    end
  end

  # Test each requirement with its specific fixtures
  REQUIREMENTS_TO_TEST = %w[
    allowed_elements
    color_restrictions
    font_family
    forbidden_content
    id_reference
    link_validation
    namespace_attributes
    namespace
    no_external_css
    style
    style_promotion
    viewbox_required
  ].freeze

  FIXTURES_BASE_DIR = "spec/fixtures"

  REQUIREMENTS_TO_TEST.each do |requirement_name|
    fixtures_dir_path = File.join(FIXTURES_BASE_DIR, requirement_name)

    # Skip if fixture directory doesn't exist
    next unless Dir.exist?(fixtures_dir_path)

    describe "#{requirement_name} requirement" do
      # Get all fixture files that have both input and expected repair versions
      fixture_files = Dir.glob(File.join(fixtures_dir_path,
                                         "inputs/*.svg")).select do |input_file|
        basename = File.basename(input_file)
        File.exist?(File.join(fixtures_dir_path, "repair", basename))
      end.map do |f|
        File.basename(f, ".svg")
      end

      fixture_files.each do |fixture_name|
        describe "fixture: #{fixture_name}" do
          let(:fixtures_dir) { File.join(FIXTURES_BASE_DIR, requirement_name) }
          let(:input_file) do
            File.join(fixtures_dir, "inputs", "#{fixture_name}.svg")
          end
          let(:expected_output_file) do
            File.join(fixtures_dir, "repair", "#{fixture_name}.svg")
          end

          it "validates input file and identifies violations" do
            skip "Input file not found" unless File.exist?(input_file)

            document = SvgConform::Document.from_file(input_file)
            profile = SvgConform::Profile.load_from_file(svg_1_2_rfc_profile_path)

            validation_result = profile.validate(document)

            # Should have violations for this test case
            expect(validation_result.valid?).to be false
            expect(validation_result.errors.count).to be > 0

            puts "Found #{validation_result.errors.count} violations in #{fixture_name}"
          end

          it "applies available remediations successfully" do
            skip "Expected repair file not found" unless File.exist?(expected_output_file)
            skip "Input file not found" unless File.exist?(input_file)

            # Load the document and apply profile remediations
            document = SvgConform::Document.from_file(input_file)
            profile = SvgConform::Profile.load_from_file(svg_1_2_rfc_profile_path)

            # Get initial error count
            initial_result = profile.validate(document)
            initial_error_count = initial_result.errors.count

            # Apply all remediations
            changes = profile.apply_remediations(document)

            # Get final error count
            final_result = profile.validate(document)
            final_error_count = final_result.errors.count

            # Show remediation progress
            puts "Remediation results for #{fixture_name}: #{initial_error_count} → #{final_error_count} errors"
            puts "  Changes applied: #{changes.count}" if changes.any?

            # For requirements with implemented remediations, expect fewer errors
            requirements_with_remediations = %w[color_restrictions font_family
                                                viewbox_required]

            if requirements_with_remediations.include?(requirement_name)
              expect(final_error_count).to be < initial_error_count
            else
              # For requirements without remediations, document the current state
              puts "  Note: No remediations available for #{requirement_name} requirement"
            end
          end

          it "maintains XML structure integrity after processing" do
            skip "Input file not found" unless File.exist?(input_file)

            # Load the document and apply profile remediations
            document = SvgConform::Document.from_file(input_file)
            profile = SvgConform::Profile.load_from_file(svg_1_2_rfc_profile_path)

            # Apply all remediations
            profile.apply_remediations(document)

            # Should still be valid XML
            expect(document.to_xml).to match(/<svg\s+[^>]*>.*<\/svg>/m)

            # Should maintain root element structure
            expect(document.root.name).to eq("svg")
          end
        end
      end
    end
  end

  describe "comprehensive test" do
    let(:comprehensive_input) do
      "spec/fixtures/comprehensive/inputs/multiple_violations.svg"
    end
    let(:comprehensive_expected) do
      "spec/fixtures/comprehensive/repair/multiple_violations.svg"
    end

    it "handles multiple violations across different requirements" do
      skip "Comprehensive fixtures not found" unless File.exist?(comprehensive_input)

      document = SvgConform::Document.from_file(comprehensive_input)
      profile = SvgConform::Profile.load_from_file(svg_1_2_rfc_profile_path)

      # Initial validation should show multiple violations
      initial_result = profile.validate(document)
      expect(initial_result.valid?).to be false
      expect(initial_result.errors.count).to be > 5

      # Apply remediations
      changes = profile.apply_remediations(document)
      expect(changes).not_to be_empty

      # Final validation should be much better
      final_result = profile.validate(document)
      expect(final_result.errors.count).to be < initial_result.errors.count

      puts "Comprehensive test: #{initial_result.errors.count} → #{final_result.errors.count} violations"
    end
  end

  describe "IETF-test.svg (issue #75)" do
    let(:ietf_test_file) do
      "spec/fixtures/svg_1_2_rfc/inputs/ietf_test_violations.svg"
    end
    let(:expected_errors_file) do
      "spec/fixtures/svg_1_2_rfc/expected_errors/ietf_test_violations.yml"
    end

    it "validates IETF-test.svg and detects expected violations" do
      skip "IETF-test fixture not found" unless File.exist?(ietf_test_file)

      document = SvgConform::Document.from_file(ietf_test_file)
      profile = SvgConform::Profile.load_from_file(svg_1_2_rfc_profile_path)

      # Validate using DOM mode (required for remediation)
      result = profile.validate(document)

      # Should detect violations
      expect(result.valid?).to be false

      # Should have exactly 18 errors (3 color + 15 style promotion)
      expect(result.errors.count).to eq(18)

      # Group errors by requirement
      errors_by_requirement = {}
      result.errors.each do |error|
        req_id = error.requirement_id || "unknown"
        errors_by_requirement[req_id] ||= []
        errors_by_requirement[req_id] << error
      end

      # Check color_restrictions errors
      color_errors = errors_by_requirement["color_restrictions"] || []
      expect(color_errors.count).to eq(3)

      color_stroke_errors = color_errors.select { |e| e.message.include?("stroke") }
      color_fill_errors = color_errors.select { |e| e.message.include?("fill") }
      expect(color_stroke_errors.count).to eq(2)
      expect(color_fill_errors.count).to eq(1)

      # Check style_promotion errors
      style_errors = errors_by_requirement["style_promotion"] || []
      expect(style_errors.count).to eq(15)

      # Count specific style properties
      style_props = {}
      style_errors.each do |error|
        if error.message =~ /Style property '([-\w]+)' can be promoted/
          style_props[$1] ||= 0
          style_props[$1] += 1
        end
      end

      expect(style_props["stroke"]).to eq(4)
      expect(style_props["stroke-width"]).to eq(2)
      expect(style_props["fill"]).to eq(6)
      expect(style_props["font-family"]).to eq(1)
      expect(style_props["font-size"]).to eq(1)

      puts "IETF-test.svg validation: #{result.errors.count} errors detected"
      puts "  Color errors: #{color_errors.count}"
      puts "  Style promotion errors: #{style_errors.count}"
    end

    it "applies remediations to IETF-test.svg and reduces errors" do
      skip "IETF-test fixture not found" unless File.exist?(ietf_test_file)

      document = SvgConform::Document.from_file(ietf_test_file)
      profile = SvgConform::Profile.load_from_file(svg_1_2_rfc_profile_path)

      # Get initial error count
      initial_result = profile.validate(document)
      initial_error_count = initial_result.errors.count

      # Apply all remediations
      changes = profile.apply_remediations(document)

      # Get final error count
      final_result = profile.validate(document)
      final_error_count = final_result.errors.count

      # Verify remediation was applied
      expect(changes.count).to be > 0

      # Verify errors were reduced
      expect(final_error_count).to be < initial_error_count

      # Verify specific error reduction
      expect(initial_error_count).to eq(18)
      expect(final_error_count).to eq(1)

      # Verify specific remediations were applied
      color_changes = changes.select { |c| c[:type] == :attribute_modified || c[:message]&.include?("color") }
      style_promotion_changes = changes.select { |c| c[:type] == :style_promotion || c[:message]&.include?("promoted") }

      expect(color_changes.count).to be > 0
      expect(style_promotion_changes.count).to be > 0

      puts "IETF-test.svg remediation: #{initial_error_count} → #{final_error_count} errors"
      puts "  Total changes: #{changes.count}"
      puts "    - Color conversion: #{color_changes.count}"
      puts "    - Style promotion: #{style_promotion_changes.count}"
    end

    it "produces valid XML after remediation" do
      skip "IETF-test fixture not found" unless File.exist?(ietf_test_file)

      document = SvgConform::Document.from_file(ietf_test_file)
      profile = SvgConform::Profile.load_from_file(svg_1_2_rfc_profile_path)

      # Apply remediations
      profile.apply_remediations(document)

      # Should still be valid XML
      xml = document.to_xml
      expect(xml).to match(/<svg\s+[^>]*>.*<\/svg>/m)

      # Should maintain root element structure
      expect(document.root.name).to eq("svg")

      # Verify specific remediations in output
      # Remediation promotes styles to attributes (e.g., stroke="black")
      # and also has some fill="black" attributes from color conversion
      xml = document.to_xml

      # Check for promoted stroke attributes (from style promotion)
      expect(xml).to include('stroke="black"')

      # Check for stroke-width attributes (from style promotion)
      expect(xml).to include('stroke-width="88"')

      # Check for fill attributes (from both color conversion and style promotion)
      expect(xml).to include('fill="black"').or(include('fill="none"'))
    end
  end
end
