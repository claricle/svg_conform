# frozen_string_literal: true

require 'spec_helper'
require 'canon'

RSpec.describe SvgConform::Requirements::FontFamilyRequirement do
  let(:fixtures_dir) { 'spec/fixtures/font_family' }

  # Get all fixture files that have both input and expected repair versions
  fixture_files = Dir.glob('spec/fixtures/font_family/inputs/*.svg').select do |input_file|
    basename = File.basename(input_file)
    File.exist?("spec/fixtures/font_family/repair/#{basename}")
  end.map { |f| File.basename(f, '.svg') }

  fixture_files.each do |fixture_name|
    describe "fixture: #{fixture_name}" do
      let(:input_file) { "spec/fixtures/font_family/inputs/#{fixture_name}.svg" }
      let(:expected_output_file) { "spec/fixtures/font_family/repair/#{fixture_name}.svg" }

      it 'validates input file and identifies font family violations' do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: 'font_family',
          description: 'Test font family requirement',
          allowed_families: %w[serif sans-serif monospace],
          default_family: 'sans-serif'
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        expect(context.errors).not_to be_empty
        puts "Found #{context.errors.count} font family violations in #{fixture_name}"

        context.errors.each do |error|
          expect(error.requirement_id).to eq('font_family')
          expect(error.message).to be_a(String)
          expect(error.message).not_to be_empty
        end
      end

      it 'correctly identifies specific font family violations' do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: 'font_family',
          description: 'Test font family requirement',
          allowed_families: %w[serif sans-serif monospace],
          default_family: 'sans-serif'
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        # Check that errors are specific to invalid font families
        context.errors.each do |error|
          expect(error.message).to match(/font.*family|Invalid font family/i)
        end
      end

      it 'passes validation for documents with only allowed font families' do
        # Create a simple valid document for testing
        valid_svg = <<~SVG
          <?xml version="1.0"?>
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
            <text x="10" y="20" font-family="serif">Serif Text</text>
            <text x="10" y="40" font-family="sans-serif">Sans Serif Text</text>
            <text x="10" y="60" font-family="monospace">Monospace Text</text>
          </svg>
        SVG

        document = SvgConform::Document.from_content(valid_svg)
        requirement = described_class.new(
          id: 'font_family',
          description: 'Test font family requirement',
          allowed_families: %w[serif sans-serif monospace],
          default_family: 'sans-serif'
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        expect(context.errors).to be_empty
      end
    end
  end

  describe 'configuration' do
    it 'accepts custom allowed font families list' do
      requirement = described_class.new(
        id: 'test_font_family',
        description: 'Test with custom font families',
        allowed_families: %w[Arial Helvetica Times]
      )

      expect(requirement.allowed_families).to eq(%w[Arial Helvetica Times])
    end

    it 'supports default fallback configuration' do
      requirement = described_class.new(
        id: 'test_font_family',
        description: 'Test default fallback',
        default_fallback: 'serif'
      )

      expect(requirement.default_fallback).to eq('serif')
    end

    it 'has default allowed families' do
      requirement = described_class.new(
        id: 'test_font_family',
        description: 'Test requirement'
      )

      expect(requirement.allowed_families).to eq(%w[serif sans-serif monospace])
    end
  end

  describe 'font family validation logic' do
    let(:requirement) do
      described_class.new(
        id: 'test_font_family',
        description: 'Test font family requirement',
        allowed_families: %w[serif sans-serif monospace],
        default_family: 'sans-serif'
      )
    end

    it 'detects invalid font families in font-family attributes' do
      invalid_svg = <<~SVG
        <?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <text x="10" y="20" font-family="Times New Roman">Invalid Font</text>
        </svg>
      SVG

      document = SvgConform::Document.from_content(invalid_svg)
      context = SvgConform::ValidationContext.new(document, nil)
      requirement.validate_document(document, context)

      expect(context.errors).not_to be_empty
      expect(context.errors.first.message).to match(/Times New Roman/i)
    end

    it 'detects invalid font families in style attributes' do
      invalid_svg = <<~SVG
        <?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <text x="10" y="20" style="font-family: Arial">Invalid Font in Style</text>
        </svg>
      SVG

      document = SvgConform::Document.from_content(invalid_svg)
      context = SvgConform::ValidationContext.new(document, nil)
      requirement.validate_document(document, context)

      expect(context.errors).not_to be_empty
      expect(context.errors.first.message).to match(/Arial/i)
    end

    it 'handles font family lists correctly' do
      invalid_svg = <<~SVG
        <?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <text x="10" y="20" font-family="Arial, sans-serif">Mixed Font List</text>
        </svg>
      SVG

      document = SvgConform::Document.from_content(invalid_svg)
      context = SvgConform::ValidationContext.new(document, nil)
      requirement.validate_document(document, context)

      expect(context.errors).not_to be_empty
      expect(context.errors.first.message).to match(/Arial/i)
    end
  end
end
