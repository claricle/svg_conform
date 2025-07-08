# frozen_string_literal: true

require 'spec_helper'
require 'canon'

RSpec.describe SvgConform::Requirements::AllowedElementsRequirement do
  let(:fixtures_dir) { 'spec/fixtures/allowed_elements' }

  # Get all fixture files that have both input and expected repair versions
  fixture_files = Dir.glob('spec/fixtures/allowed_elements/inputs/*.svg').select do |input_file|
    basename = File.basename(input_file)
    File.exist?("spec/fixtures/allowed_elements/repair/#{basename}")
  end.map { |f| File.basename(f, '.svg') }

  fixture_files.each do |fixture_name|
    describe "fixture: #{fixture_name}" do
      let(:input_file) { "spec/fixtures/allowed_elements/inputs/#{fixture_name}.svg" }
      let(:expected_output_file) { "spec/fixtures/allowed_elements/repair/#{fixture_name}.svg" }

      it 'validates input file and identifies violations' do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: 'allowed_elements',
          description: 'Test allowed elements requirement',
          disallowed_elements: %w[script audio video animate animateColor clipPath marker]
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        expect(context.errors).not_to be_empty
        puts "Found #{context.errors.count} violations in #{fixture_name}"

        context.errors.each do |error|
          expect(error.requirement_id).to eq('allowed_elements')
          expect(error.message).to be_a(String)
          expect(error.message).not_to be_empty
        end
      end

      it 'correctly identifies specific violations' do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: 'allowed_elements',
          description: 'Test allowed elements requirement',
          disallowed_elements: %w[script audio video animate animateColor clipPath marker]
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        # Check that errors are specific to disallowed elements or attributes
        context.errors.each do |error|
          expect(error.message).to match(/Element .* is not allowed|Attribute .* is not allowed/)
        end
      end

      it 'passes validation for documents with only allowed elements' do
        # Create a simple valid document for testing
        allowed_svg = <<~SVG
          <?xml version="1.0"?>
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
            <g>
              <rect x="10" y="10" width="20" height="20" fill="black"/>
              <circle cx="50" cy="50" r="10" fill="black"/>
              <text x="10" y="80">Test</text>
            </g>
          </svg>
        SVG

        document = SvgConform::Document.from_content(allowed_svg)
        requirement = described_class.new(
          id: 'allowed_elements',
          description: 'Test allowed elements requirement',
          disallowed_elements: %w[]  # No disallowed elements, so it should pass
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        expect(context.errors).to be_empty
      end
    end
  end

  describe 'configuration' do
    it 'accepts custom allowed elements list' do
      requirement = described_class.new(
        id: 'test_allowed_elements',
        description: 'Test with custom elements',
        disallowed_elements: %w[script iframe embed]
      )

      expect(requirement.disallowed_elements).to eq(%w[script iframe embed])
    end

    it 'can be instantiated with basic parameters' do
      requirement = described_class.new(
        id: 'test_allowed_elements',
        description: 'Test requirement'
      )

      expect(requirement).to be_a(described_class)
    end
  end
end
