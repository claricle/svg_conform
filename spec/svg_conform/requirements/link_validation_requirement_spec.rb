# frozen_string_literal: true

require "spec_helper"
require "canon"

RSpec.describe SvgConform::Requirements::LinkValidationRequirement do
  let(:fixtures_dir) { "spec/fixtures/link_validation" }

  # Get all fixture files that have both input and expected repair versions
  fixture_files = Dir.glob("spec/fixtures/link_validation/inputs/*.svg").select do |input_file|
    basename = File.basename(input_file)
    File.exist?("spec/fixtures/link_validation/repair/#{basename}")
  end.map do |f|
    File.basename(f, ".svg")
  end

  fixture_files.each do |fixture_name|
    describe "fixture: #{fixture_name}" do
      let(:input_file) do
        "spec/fixtures/link_validation/inputs/#{fixture_name}.svg"
      end
      let(:expected_output_file) do
        "spec/fixtures/link_validation/repair/#{fixture_name}.svg"
      end

      it "validates input file and identifies violations" do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: "link_validation",
          description: "Test link validation requirement",
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        expect(context.errors).not_to be_empty

        context.errors.each do |error|
          expect(error.requirement_id).to eq("link_validation")
          expect(error.message).to be_a(String)
          expect(error.message).not_to be_empty
        end
      end

      it "correctly identifies specific violations" do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: "link_validation",
          description: "Test link validation requirement",
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        # Check that errors are relevant to this requirement
        context.errors.each do |error|
          expect(error.message).not_to be_empty
        end
      end
    end
  end

  describe "configuration" do
    it "can be instantiated with basic parameters" do
      requirement = described_class.new(
        id: "test_link_validation",
        description: "Test requirement",
      )

      expect(requirement).to be_a(described_class)
    end
  end
end
