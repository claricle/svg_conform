# frozen_string_literal: true

# Shared examples for testing both DOM and SAX validation modes
RSpec.shared_examples "validates in both DOM and SAX modes" do |file_path, profile_name|
  let(:file_path) { file_path }
  let(:profile) { profile_name }

  it "produces identical results in DOM and SAX modes" do
    dom_result = SvgConform::Validator.new(mode: :dom).validate_file(file_path, profile: profile)
    sax_result = SvgConform::Validator.new(mode: :sax).validate_file(file_path, profile: profile)

    expect(sax_result.errors.size).to eq(dom_result.errors.size),
      "SAX mode should produce same error count as DOM mode (DOM: #{dom_result.errors.size}, SAX: #{sax_result.errors.size})"

    expect(sax_result.warnings.size).to eq(dom_result.warnings.size),
      "SAX mode should produce same warning count as DOM mode"

    expect(sax_result.valid?).to eq(dom_result.valid?),
      "SAX mode should have same validity as DOM mode"
  end

  it "DOM mode validates correctly" do
    result = SvgConform::Validator.new(mode: :dom).validate_file(file_path, profile: profile)
    expect(result).to be_a(SvgConform::ValidationResult)
  end

  it "SAX mode validates correctly" do
    result = SvgConform::Validator.new(mode: :sax).validate_file(file_path, profile: profile)
    expect(result).to be_a(SvgConform::ValidationResult)
  end

  describe "performance comparison" do
    it "SAX mode is faster than or equal to DOM mode" do
      skip "Performance test - run manually for large files"

      dom_time = Benchmark.realtime do
        SvgConform::Validator.new(mode: :dom).validate_file(file_path, profile: profile)
      end

      sax_time = Benchmark.realtime do
        SvgConform::Validator.new(mode: :sax).validate_file(file_path, profile: profile)
      end

      expect(sax_time).to be <= dom_time
    end
  end
end

RSpec.shared_examples "validates content in both modes" do |svg_content, profile_name|
  let(:content) { svg_content }
  let(:profile) { profile_name }

  it "produces identical results for content validation" do
    dom_result = SvgConform::Validator.new(mode: :dom).validate(content, profile: profile)
    sax_result = SvgConform::Validator.new(mode: :sax).validate(content, profile: profile)

    expect(sax_result.errors.size).to eq(dom_result.errors.size),
      "SAX mode should produce same error count as DOM mode (DOM: #{dom_result.errors.size}, SAX: #{sax_result.errors.size})"

    expect(sax_result.valid?).to eq(dom_result.valid?),
      "SAX mode should have same validity as DOM mode"
  end
end