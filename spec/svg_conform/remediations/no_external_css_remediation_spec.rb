# frozen_string_literal: true

require "spec_helper"
require "canon"

RSpec.describe SvgConform::Remediations::NoExternalCssRemediation do
  let(:fixtures_dir) { "spec/fixtures/no_external_css" }

  # Get all fixture files that have both input and expected repair versions
  fixture_files = Dir.glob("spec/fixtures/no_external_css/inputs/*.svg").select do |input_file|
    basename = File.basename(input_file)
    File.exist?("spec/fixtures/no_external_css/repair/#{basename}")
  end.map do |f|
    File.basename(f, ".svg")
  end

  fixture_files.each do |fixture_name|
    describe "fixture: #{fixture_name}" do
      let(:input_file) do
        "spec/fixtures/no_external_css/inputs/#{fixture_name}.svg"
      end
      let(:expected_output_file) do
        "spec/fixtures/no_external_css/repair/#{fixture_name}.svg"
      end

      it "applies remediation and produces expected output" do
        skip "Input file not found" unless File.exist?(input_file)
        skip "Expected output file not found" unless File.exist?(expected_output_file)

        document = SvgConform::Document.from_file(input_file)
        remediation = described_class.new(
          id: "no_external_css_fix",
          description: "Test no external css remediation",
        )

        # Apply the remediation
        context = SvgConform::ValidationContext.new(document, nil)
        changes = remediation.apply(document, context)

        # Verify changes were made
        expect(changes).to be_an(Array)
        puts "Applied #{changes.count} changes in #{fixture_name}" if changes.any?

        # Get the remediated XML
        actual_xml = document.to_xml
        expected_xml = File.read(expected_output_file)

        # Use canon matcher for XML equivalence
        expect(actual_xml).to be_analogous_with(expected_xml)
      end

      it "produces valid XML after remediation" do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        remediation = described_class.new(
          id: "no_external_css_fix",
          description: "Test no external css remediation",
        )

        # Apply the remediation
        context = SvgConform::ValidationContext.new(document, nil)
        remediation.apply(document, context)

        # Get the remediated XML
        actual_xml = document.to_xml

        # Basic XML validity check
        expect(actual_xml).to include("<svg")
        expect(actual_xml).to include("</svg>")
        expect do
          SvgConform::Document.from_content(actual_xml)
        end.not_to raise_error
      end
    end
  end

  describe "configuration" do
    it "can be instantiated with basic parameters" do
      remediation = described_class.new(
        id: "test_no_external_css_fix",
        description: "Test remediation",
      )

      expect(remediation).to be_a(described_class)
    end

    it "responds to apply method" do
      remediation = described_class.new(
        id: "test_no_external_css_fix",
        description: "Test remediation",
      )

      expect(remediation).to respond_to(:apply)
    end
  end
end
