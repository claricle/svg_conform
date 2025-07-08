# frozen_string_literal: true

require 'spec_helper'
require 'canon'

RSpec.describe SvgConform::Remediations::StylePromotionRemediation do
  let(:fixtures_dir) { 'spec/fixtures/style_promotion' }

  # Get all fixture files that have both input and expected repair versions
  fixture_files = Dir.glob('spec/fixtures/style_promotion/inputs/*.svg').select do |input_file|
    basename = File.basename(input_file)
    File.exist?("spec/fixtures/style_promotion/repair/#{basename}")
  end.map { |f| File.basename(f, '.svg') }

  fixture_files.each do |fixture_name|
    describe "fixture: #{fixture_name}" do
      let(:input_file) { "spec/fixtures/style_promotion/inputs/#{fixture_name}.svg" }
      let(:expected_output_file) { "spec/fixtures/style_promotion/repair/#{fixture_name}.svg" }

      it 'applies remediation and produces expected output' do
        skip "Input file not found" unless File.exist?(input_file)
        skip "Expected output file not found" unless File.exist?(expected_output_file)

        document = SvgConform::Document.from_file(input_file)
        remediation = described_class.new(
          id: 'style_promotion_fix',
          description: 'Test style promotion remediation'
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

      it 'produces valid XML after remediation' do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        remediation = described_class.new(
          id: 'style_promotion_fix',
          description: 'Test style promotion remediation'
        )

        # Apply the remediation
        context = SvgConform::ValidationContext.new(document, nil)
        changes = remediation.apply(document, context)

        # Get the remediated XML
        actual_xml = document.to_xml

        # Basic XML validity check
        expect(actual_xml).to include('<svg')
        expect(actual_xml).to include('</svg>')
        expect { SvgConform::Document.from_content(actual_xml) }.not_to raise_error
      end
    end
  end

  describe 'configuration' do
    it 'can be instantiated with basic parameters' do
      remediation = described_class.new(
        id: 'test_style_promotion_fix',
        description: 'Test remediation'
      )

      expect(remediation).to be_a(described_class)
    end

    it 'responds to apply method' do
      remediation = described_class.new(
        id: 'test_style_promotion_fix',
        description: 'Test remediation'
      )

      expect(remediation).to respond_to(:apply)
    end
  end
end
