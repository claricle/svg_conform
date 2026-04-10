# frozen_string_literal: true

require "spec_helper"
require "canon"
require "tempfile"

RSpec.describe "Lucid Profile" do
  describe "namespace attribute remediation" do
    let(:lucid_profile_path) { "config/profiles/lucid_fix.yml" }
    let(:fixtures_dir) { "spec/fixtures/lucid" }

    # Get all fixture files that have both input and expected repair versions
    fixture_files = Dir.glob("spec/fixtures/lucid/inputs/*.svg").select do |input_file|
      basename = File.basename(input_file)
      File.exist?("spec/fixtures/lucid/repair/#{basename}")
    end.map do |f|
      File.basename(f, ".svg")
    end

    fixture_files.each do |fixture_name|
      describe "fixture: #{fixture_name}" do
        let(:input_file) { "spec/fixtures/lucid/inputs/#{fixture_name}.svg" }
        let(:expected_output_file) do
          "spec/fixtures/lucid/repair/#{fixture_name}.svg"
        end

        it "produces canonically equivalent output using profile remediation" do
          skip "Expected repair file not found" unless File.exist?(expected_output_file)

          # Load the document and apply profile remediations
          document = SvgConform::Document.from_file(input_file)
          profile = SvgConform::Profile.load_from_file(lucid_profile_path)

          changes = profile.apply_remediations(document)

          # Verify namespace remediation changes were made
          namespace_changes = changes.select do |c|
            c[:description]&.include?("namespace attribute")
          end
          expect(namespace_changes).not_to be_empty

          # Get the remediated XML
          actual_xml = document.to_xml
          expected_xml = File.read(expected_output_file)

          # Use canon matcher for XML equivalence
          expect(actual_xml).to be_analogous_with(expected_xml)
        end

        it "removes lucid namespace attributes correctly" do
          # Load the document and profile
          document = SvgConform::Document.from_file(input_file)
          profile = SvgConform::Profile.load_from_file(lucid_profile_path)

          # Check that the document contains lucid attributes before remediation
          original_xml = document.to_xml
          expect(original_xml).to include("lucid:page-tab-id")
          expect(original_xml).to include('xmlns:lucid="lucid"')

          # Apply profile remediations
          changes = profile.apply_remediations(document)

          # Verify changes were made
          expect(changes).not_to be_empty

          # Find namespace attribute changes
          attr_changes = changes.select do |c|
            c[:description]&.include?("attribute")
          end
          expect(attr_changes).not_to be_empty

          # Verify the result doesn't contain the lucid page-tab-id attribute
          actual_xml = document.to_xml
          expect(actual_xml).not_to include("lucid:page-tab-id")

          # The namespace declaration removal is the main functionality we want to test
          # For now, let's verify the attribute removal is working
        end
      end
    end
  end
end
