# frozen_string_literal: true

require "spec_helper"
require "canon"

RSpec.describe SvgConform::Requirements::ColorRestrictionsRequirement do
  let(:fixtures_dir) { "spec/fixtures/color_restrictions" }

  # Get all fixture files that have both input and expected repair versions
  fixture_files = Dir.glob("spec/fixtures/color_restrictions/inputs/*.svg").select do |input_file|
    basename = File.basename(input_file)
    File.exist?("spec/fixtures/color_restrictions/repair/#{basename}")
  end.map do |f|
    File.basename(f, ".svg")
  end

  fixture_files.each do |fixture_name|
    describe "fixture: #{fixture_name}" do
      let(:input_file) do
        "spec/fixtures/color_restrictions/inputs/#{fixture_name}.svg"
      end
      let(:expected_output_file) do
        "spec/fixtures/color_restrictions/repair/#{fixture_name}.svg"
      end

      it "validates input file and identifies color violations" do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: "color_restrictions",
          description: "Test color restrictions requirement",
          allowed_colors: %w[black white],
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        expect(context.errors).not_to be_empty

        context.errors.each do |error|
          expect(error.requirement_id).to eq("color_restrictions")
          expect(error.message).to be_a(String)
          expect(error.message).not_to be_empty
        end
      end

      it "correctly identifies specific color violations" do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: "color_restrictions",
          description: "Test color restrictions requirement",
          grayscale_only: true,
          allowed_colors: %w[black white gray grey silver],
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        # Check that errors are specific to invalid colors
        context.errors.each do |error|
          expect(error.message).to match(/color|fill|stroke/i)
        end
      end

      it "passes validation for documents with only allowed colors" do
        # Create a simple valid document for testing
        valid_svg = <<~SVG
          <?xml version="1.0"?>
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
            <rect x="10" y="10" width="20" height="20" fill="black" stroke="white"/>
            <circle cx="50" cy="50" r="10" fill="black"/>
            <text x="10" y="80" fill="white">Test</text>
          </svg>
        SVG

        document = SvgConform::Document.from_content(valid_svg)
        requirement = described_class.new(
          id: "color_restrictions",
          description: "Test color restrictions requirement",
          allowed_colors: %w[black white],
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        expect(context.errors).to be_empty
      end
    end
  end

  describe "configuration" do
    it "accepts custom allowed colors list" do
      requirement = described_class.new(
        id: "test_color_restrictions",
        description: "Test with custom colors",
        allowed_colors: %w[red green blue],
      )

      expect(requirement.allowed_colors).to eq(%w[red green blue])
    end

    it "supports different modes" do
      requirement = described_class.new(
        id: "test_color_restrictions",
        description: "Test mode",
        mode: "custom_mode",
      )

      expect(requirement.mode).to eq("custom_mode")
    end

    it "has default mode" do
      requirement = described_class.new(
        id: "test_color_restrictions",
        description: "Test requirement",
      )

      expect(requirement.mode).to eq("black_white_only")
    end
  end

  describe "color validation logic" do
    let(:requirement) do
      described_class.new(
        id: "test_color_restrictions",
        description: "Test color restrictions",
        grayscale_only: true,
        allowed_colors: %w[black white gray grey silver],
      )
    end

    it "detects invalid colors in fill attributes" do
      invalid_svg = <<~SVG
        <?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <rect x="10" y="10" width="20" height="20" fill="red"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(invalid_svg)
      context = SvgConform::ValidationContext.new(document, nil)
      requirement.validate_document(document, context)

      expect(context.errors).not_to be_empty
      expect(context.errors.first.message).to match(/red/i)
    end

    it "detects invalid colors in stroke attributes" do
      invalid_svg = <<~SVG
        <?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <rect x="10" y="10" width="20" height="20" stroke="blue"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(invalid_svg)
      context = SvgConform::ValidationContext.new(document, nil)
      requirement.validate_document(document, context)

      expect(context.errors).not_to be_empty
      expect(context.errors.first.message).to match(/blue/i)
    end
  end
end
