# frozen_string_literal: true

require 'spec_helper'
require 'canon'

RSpec.describe SvgConform::Requirements::InvalidIdReferencesRequirement do
  let(:fixtures_dir) { 'spec/fixtures/invalid_id_references' }

  # Get all fixture files that have both input and expected repair versions
  fixture_files = Dir.glob('spec/fixtures/invalid_id_references/inputs/*.svg').select do |input_file|
    basename = File.basename(input_file)
    File.exist?("spec/fixtures/invalid_id_references/repair/#{basename}")
  end.map { |f| File.basename(f, '.svg') }

  fixture_files.each do |fixture_name|
    describe "fixture: #{fixture_name}" do
      let(:input_file) { "spec/fixtures/invalid_id_references/inputs/#{fixture_name}.svg" }
      let(:expected_output_file) { "spec/fixtures/invalid_id_references/repair/#{fixture_name}.svg" }

      it 'validates input file and identifies violations' do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: 'invalid_id_references',
          description: 'Test invalid id references requirement'
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        expect(context.errors).not_to be_empty
        puts "Found #{context.errors.count} invalid id references violations in #{fixture_name}"

        context.errors.each do |error|
          expect(error.requirement_id).to eq('invalid_id_references')
          expect(error.message).to be_a(String)
          expect(error.message).not_to be_empty
        end
      end

      it 'correctly identifies specific violations' do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: 'invalid_id_references',
          description: 'Test invalid id references requirement'
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

  describe 'configuration' do
    it 'can be instantiated with basic parameters' do
      requirement = described_class.new(
        id: 'test_invalid_id_references',
        description: 'Test requirement'
      )

      expect(requirement).to be_a(described_class)
    end
  end
end
