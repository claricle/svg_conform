# frozen_string_literal: true

require "spec_helper"
require "canon"

RSpec.describe SvgConform::Requirements::ForbiddenContentRequirement do
  let(:fixtures_dir) { "spec/fixtures/forbidden_content" }

  # Get all fixture files that have both input and expected repair versions
  fixture_files = Dir.glob("spec/fixtures/forbidden_content/inputs/*.svg").select do |input_file|
    basename = File.basename(input_file)
    File.exist?("spec/fixtures/forbidden_content/repair/#{basename}")
  end.map do |f|
    File.basename(f, ".svg")
  end

  fixture_files.each do |fixture_name|
    describe "fixture: #{fixture_name}" do
      let(:input_file) do
        "spec/fixtures/forbidden_content/inputs/#{fixture_name}.svg"
      end
      let(:expected_output_file) do
        "spec/fixtures/forbidden_content/repair/#{fixture_name}.svg"
      end

      it "validates input file and identifies forbidden content violations" do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: "forbidden_content",
          description: "Test forbidden content requirement",
          forbidden_elements: %w[script audio video animate animateColor],
          forbidden_attributes: %w[onclick onmouseover onload onerror],
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        expect(context.errors).not_to be_empty

        context.errors.each do |error|
          expect(error.requirement_id).to eq("forbidden_content")
          expect(error.message).to be_a(String)
          expect(error.message).not_to be_empty
        end
      end

      it "correctly identifies specific forbidden content violations" do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: "forbidden_content",
          description: "Test forbidden content requirement",
          forbidden_elements: %w[script audio video animate animateColor],
          forbidden_attributes: %w[onclick onmouseover onload onerror],
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        # Check that errors are specific to forbidden elements or attributes
        context.errors.each do |error|
          expect(error.message).to match(/Forbidden.*element|Forbidden.*attribute/i)
        end
      end

      it "passes validation for documents without forbidden content" do
        # Create a simple valid document for testing
        valid_svg = <<~SVG
          <?xml version="1.0"?>
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
            <g>
              <rect x="10" y="10" width="20" height="20" fill="black"/>
              <circle cx="50" cy="50" r="10" fill="black"/>
              <text x="10" y="80">Safe Content</text>
            </g>
          </svg>
        SVG

        document = SvgConform::Document.from_content(valid_svg)
        requirement = described_class.new(
          id: "forbidden_content",
          description: "Test forbidden content requirement",
          forbidden_elements: %w[script audio video animate animateColor],
          forbidden_attributes: %w[onclick onmouseover onload onerror],
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        expect(context.errors).to be_empty
      end
    end
  end

  describe "configuration" do
    it "accepts custom forbidden elements list" do
      requirement = described_class.new(
        id: "test_forbidden_content",
        description: "Test with custom forbidden elements",
        forbidden_elements: %w[script iframe embed],
      )

      expect(requirement.forbidden_elements).to eq(%w[script iframe embed])
    end

    it "accepts custom forbidden attributes list" do
      requirement = described_class.new(
        id: "test_forbidden_content",
        description: "Test with custom forbidden attributes",
        forbidden_attributes: %w[onclick onload href],
      )

      expect(requirement.forbidden_attributes).to eq(%w[onclick onload href])
    end

    it "can be instantiated with basic parameters" do
      requirement = described_class.new(
        id: "test_forbidden_content",
        description: "Test requirement",
      )

      expect(requirement).to be_a(described_class)
    end
  end

  describe "forbidden content validation logic" do
    let(:requirement) do
      described_class.new(
        id: "test_forbidden_content",
        description: "Test forbidden content requirement",
        forbidden_elements: %w[script audio video],
        forbidden_attributes: %w[onclick onmouseover],
      )
    end

    it "detects forbidden elements" do
      invalid_svg = <<~SVG
        <?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <script>alert('forbidden');</script>
          <rect x="10" y="10" width="20" height="20"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(invalid_svg)
      context = SvgConform::ValidationContext.new(document, nil)
      requirement.validate_document(document, context)

      expect(context.errors).not_to be_empty
      expect(context.errors.first.message).to match(/script/i)
    end

    it "detects forbidden attributes" do
      invalid_svg = <<~SVG
        <?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <rect x="10" y="10" width="20" height="20" onclick="handleClick()"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(invalid_svg)
      context = SvgConform::ValidationContext.new(document, nil)
      requirement.validate_document(document, context)

      expect(context.errors).not_to be_empty
      expect(context.errors.first.message).to match(/onclick/i)
    end

    it "detects multiple forbidden items in one document" do
      invalid_svg = <<~SVG
        <?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <script>alert('forbidden');</script>
          <audio src="sound.mp3"/>
          <rect x="10" y="10" width="20" height="20" onclick="handleClick()" onmouseover="hover()"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(invalid_svg)
      context = SvgConform::ValidationContext.new(document, nil)
      requirement.validate_document(document, context)

      expect(context.errors.count).to be >= 4 # script, audio, onclick, onmouseover
      forbidden_items = context.errors.map(&:message).join(" ")
      expect(forbidden_items).to match(/script/i)
      expect(forbidden_items).to match(/audio/i)
      expect(forbidden_items).to match(/onclick/i)
      expect(forbidden_items).to match(/onmouseover/i)
    end
  end
end
