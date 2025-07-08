# frozen_string_literal: true

require 'spec_helper'
require 'canon'

RSpec.describe SvgConform::Requirements::NamespaceRequirement do
  let(:fixtures_dir) { 'spec/fixtures/namespace' }

  # Get all fixture files that have both input and expected repair versions
  fixture_files = Dir.glob('spec/fixtures/namespace/inputs/*.svg').select do |input_file|
    basename = File.basename(input_file)
    File.exist?("spec/fixtures/namespace/repair/#{basename}")
  end.map { |f| File.basename(f, '.svg') }

  fixture_files.each do |fixture_name|
    describe "fixture: #{fixture_name}" do
      let(:input_file) { "spec/fixtures/namespace/inputs/#{fixture_name}.svg" }
      let(:expected_output_file) { "spec/fixtures/namespace/repair/#{fixture_name}.svg" }

      it 'validates input file and identifies namespace violations' do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: 'namespace',
          description: 'Test namespace requirement',
          required_namespace: 'http://www.w3.org/2000/svg'
        )

        result = context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, result)

        expect(context.errors).not_to be_empty
        puts "Found #{context.errors.count} namespace violations in #{fixture_name}"

        context.errors.each do |error|
          expect(error.requirement_id).to eq('namespace')
          expect(error.message).to be_a(String)
          expect(error.message).not_to be_empty
        end
      end

      it 'correctly identifies specific namespace violations' do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: 'namespace',
          description: 'Test namespace requirement',
          required_namespace: 'http://www.w3.org/2000/svg'
        )

        result = context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, result)

        # Check that errors are specific to namespace issues
        context.errors.each do |error|
          expect(error.message).to match(/namespace|xmlns/i)
        end
      end

      it 'passes validation for documents with correct namespace' do
        # Create a simple valid document for testing
        valid_svg = <<~SVG
          <?xml version="1.0"?>
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
            <rect x="10" y="10" width="20" height="20" fill="black"/>
          </svg>
        SVG

        document = SvgConform::Document.from_content(valid_svg)
        requirement = described_class.new(
          id: 'namespace',
          description: 'Test namespace requirement',
          required_namespace: 'http://www.w3.org/2000/svg'
        )

        result = context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, result)

        expect(context.errors).to be_empty
      end
    end
  end

  describe 'configuration' do
    it 'accepts custom required namespace' do
      requirement = described_class.new(
        id: 'test_namespace',
        description: 'Test with custom namespace',
        required_namespace: 'http://custom.namespace.com'
      )

      expect(requirement.instance_variable_get(:@required_namespace)).to eq('http://custom.namespace.com')
    end

    it 'has default required namespace' do
      requirement = described_class.new(
        id: 'test_namespace',
        description: 'Test requirement'
      )

      expect(requirement.instance_variable_get(:@required_namespace)).to eq('http://www.w3.org/2000/svg')
    end

  end

  describe 'namespace validation logic' do
    let(:requirement) do
      described_class.new(
        id: 'test_namespace',
        description: 'Test namespace requirement',
        required_namespace: 'http://www.w3.org/2000/svg'
      )
    end

    it 'detects missing namespace on root SVG element' do
      invalid_svg = <<~SVG
        <?xml version="1.0"?>
        <svg viewBox="0 0 100 100">
          <rect x="10" y="10" width="20" height="20" fill="black"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(invalid_svg)
      result = context = SvgConform::ValidationContext.new(document, nil)
      requirement.validate_document(document, result)

      expect(context.errors).not_to be_empty
      expect(context.errors.first.message).to match(/namespace/i)
    end

    it 'detects incorrect namespace on root SVG element' do
      invalid_svg = <<~SVG
        <?xml version="1.0"?>
        <svg xmlns="http://wrong.namespace.com" viewBox="0 0 100 100">
          <rect x="10" y="10" width="20" height="20" fill="black"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(invalid_svg)
      result = context = SvgConform::ValidationContext.new(document, nil)
      requirement.validate_document(document, result)

      expect(context.errors).not_to be_empty
      expect(context.errors.first.message).to match(/namespace/i)
    end

    it 'accepts correct namespace' do
      valid_svg = <<~SVG
        <?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <rect x="10" y="10" width="20" height="20" fill="black"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(valid_svg)
      result = context = SvgConform::ValidationContext.new(document, nil)
      requirement.validate_document(document, result)

      expect(context.errors).to be_empty
    end

    it 'validates elements in wrong namespace' do
      invalid_svg = <<~SVG
        <?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <custom:element xmlns:custom="http://custom.namespace.com"/>
          <rect x="10" y="10" width="20" height="20" fill="black"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(invalid_svg)
      result = context = SvgConform::ValidationContext.new(document, nil)
      requirement.validate_document(document, result)

      expect(context.errors).not_to be_empty
      expect(context.errors.first.message).to match(/namespace.*not permitted/i)
    end
  end
end
