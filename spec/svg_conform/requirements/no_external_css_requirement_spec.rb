# frozen_string_literal: true

require "spec_helper"
require "canon"

RSpec.describe SvgConform::Requirements::NoExternalCssRequirement do
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

      it "validates input file and identifies violations" do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: "no_external_css",
          description: "Test no external css requirement",
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        expect(context.errors).not_to be_empty
        puts "Found #{context.errors.count} no external css violations in #{fixture_name}"

        context.errors.each do |error|
          expect(error.requirement_id).to eq("no_external_css")
          expect(error.message).to be_a(String)
          expect(error.message).not_to be_empty
        end
      end

      it "correctly identifies specific violations" do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: "no_external_css",
          description: "Test no external css requirement",
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
        id: "test_no_external_css",
        description: "Test requirement",
      )

      expect(requirement).to be_a(described_class)
    end
  end
end
