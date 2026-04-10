# frozen_string_literal: true

require "spec_helper"
require "canon"

RSpec.describe SvgConform::Requirements::ViewboxRequiredRequirement do
  let(:fixtures_dir) { "spec/fixtures/viewbox_required" }

  # Get all fixture files that have both input and expected repair versions
  fixture_files = Dir.glob("spec/fixtures/viewbox_required/inputs/*.svg").select do |input_file|
    basename = File.basename(input_file)
    File.exist?("spec/fixtures/viewbox_required/repair/#{basename}")
  end.map do |f|
    File.basename(f, ".svg")
  end

  fixture_files.each do |fixture_name|
    describe "fixture: #{fixture_name}" do
      let(:input_file) do
        "spec/fixtures/viewbox_required/inputs/#{fixture_name}.svg"
      end
      let(:expected_output_file) do
        "spec/fixtures/viewbox_required/repair/#{fixture_name}.svg"
      end

      it "validates input file and identifies viewbox violations" do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: "viewbox_required",
          description: "Test viewbox required requirement",
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        expect(context.errors).not_to be_empty

        context.errors.each do |error|
          expect(error.requirement_id).to eq("viewbox_required")
          expect(error.message).to be_a(String)
          expect(error.message).not_to be_empty
        end
      end

      it "correctly identifies missing viewbox attribute" do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: "viewbox_required",
          description: "Test viewbox required requirement",
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        # Check that the primary error is about missing viewBox attribute
        # (there may be additional informational errors about calculated viewBox)
        primary_error = context.errors.first
        expect(primary_error.message).to match(/viewBox.*attribute|must have.*viewBox/i)
      end

      it "passes validation for documents with viewBox attribute" do
        # Create a simple valid document for testing
        valid_svg = <<~SVG
          <?xml version="1.0"?>
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
            <rect x="10" y="10" width="20" height="20" fill="black"/>
          </svg>
        SVG

        document = SvgConform::Document.from_content(valid_svg)
        requirement = described_class.new(
          id: "viewbox_required",
          description: "Test viewbox required requirement",
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        expect(context.errors).to be_empty
      end
    end
  end

  describe "configuration" do
    it "can be instantiated with basic parameters" do
      requirement = described_class.new(
        id: "test_viewbox_required",
        description: "Test requirement",
      )

      expect(requirement).to be_a(described_class)
    end
  end

  describe "viewbox validation logic" do
    let(:requirement) do
      described_class.new(
        id: "test_viewbox_required",
        description: "Test viewbox required requirement",
      )
    end

    it "detects missing viewBox on root SVG element" do
      invalid_svg = <<~SVG
        <?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <rect x="10" y="10" width="20" height="20" fill="black"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(invalid_svg)
      context = SvgConform::ValidationContext.new(document, nil)
      requirement.validate_document(document, context)

      expect(context.errors).not_to be_empty
      expect(context.errors.first.message).to match(/viewBox/i)
    end

    it "accepts valid viewBox attribute" do
      valid_svg = <<~SVG
        <?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <rect x="10" y="10" width="20" height="20" fill="black"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(valid_svg)
      context = SvgConform::ValidationContext.new(document, nil)
      requirement.validate_document(document, context)

      expect(context.errors).to be_empty
    end

    it "validates viewBox format" do
      # Test different viewBox formats
      valid_formats = [
        "0 0 100 100",
        "0.0 0.0 100.5 100.5",
        "-10 -10 120 120",
        "  0   0   100   100  ",
      ]

      valid_formats.each do |viewbox_value|
        valid_svg = <<~SVG
          <?xml version="1.0"?>
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="#{viewbox_value}">
            <rect x="10" y="10" width="20" height="20" fill="black"/>
          </svg>
        SVG

        document = SvgConform::Document.from_content(valid_svg)
        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        expect(context.errors).to be_empty,
                                  "ViewBox '#{viewbox_value}' should be valid"
      end
    end
  end
end
