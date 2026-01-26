# frozen_string_literal: true

RSpec.describe SvgConform do
  it "has a version number" do
    expect(SvgConform::VERSION).not_to be_nil
  end

  it "validates SVG documents" do
    svg_content = <<~SVG
      <svg width="100" height="100">
        <rect x="10" y="10" width="50" height="50" fill="red"/>
      </svg>
    SVG

    validator = SvgConform::Validator.new
    result = validator.validate(svg_content, profile: :svg_1_2_rfc)

    expect(result).to respond_to(:valid?)
    expect(result).to respond_to(:errors)
    expect(result).to respond_to(:warnings)
  end

  it "loads profiles correctly" do
    svg_1_2_rfc_profile = SvgConform::Profiles.get(:svg_1_2_rfc)
    expect(svg_1_2_rfc_profile).not_to be_nil
    expect(svg_1_2_rfc_profile.requirements).not_to be_empty

    css_profile = SvgConform::Profiles.get(:no_external_css)
    expect(css_profile).not_to be_nil
    expect(css_profile.requirements).not_to be_empty
  end

  describe "profile switching without state leakage" do
    let(:svg_with_invalid_ref) do
      <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" version="1.2" viewBox="0 0 100 100">
          <defs>
            <rect id="valid-rect" width="10" height="10"/>
          </defs>
          <use href="#valid-rect" x="10" y="10"/>
          <use href="#invalid-rect" x="20" y="20"/>
        </svg>
      SVG
    end

    it "maintains consistent validation results when switching between profiles" do
      validator = SvgConform::Validator.new(mode: :sax)

      # First validation with metanorma profile
      profile_meta = SvgConform::Profiles.get("metanorma")
      result_meta1 = validator.validate(svg_with_invalid_ref, profile: profile_meta)
      first_meta_count = result_meta1.errors.count

      # Validation with svg_1_2_rfc profile
      profile_rfc = SvgConform::Profiles.get("svg_1_2_rfc")
      result_rfc1 = validator.validate(svg_with_invalid_ref, profile: profile_rfc)
      first_rfc_count = result_rfc1.errors.count

      # Second validation with metanorma profile (should match first)
      result_meta2 = validator.validate(svg_with_invalid_ref, profile: profile_meta)
      second_meta_count = result_meta2.errors.count

      # Second validation with svg_1_2_rfc profile (should match first)
      result_rfc2 = validator.validate(svg_with_invalid_ref, profile: profile_rfc)
      second_rfc_count = result_rfc2.errors.count

      # Verify consistency - no state leakage between profiles
      expect(first_meta_count).to eq(second_meta_count),
                                  "metanorma profile should return consistent results (#{first_meta_count} vs #{second_meta_count})"

      expect(first_rfc_count).to eq(second_rfc_count),
                                 "svg_1_2_rfc profile should return consistent results (#{first_rfc_count} vs #{second_rfc_count})"
    end

    it "properly resets requirement state between validations" do
      # This test specifically verifies that requirement state is reset
      # by validating the same content multiple times
      validator = SvgConform::Validator.new(mode: :sax)
      profile = SvgConform::Profiles.get("svg_1_2_rfc")

      results = []
      3.times do
        result = validator.validate(svg_with_invalid_ref, profile: profile)
        results << result.errors.count
      end

      # All runs should produce the same error count
      expect(results.uniq.size).to eq(1),
                                   "All validation runs should produce identical results: #{results.inspect}"
    end

    it "handles interleaved profile validations correctly" do
      validator = SvgConform::Validator.new(mode: :sax)

      profile_meta = SvgConform::Profiles.get("metanorma")
      profile_rfc = SvgConform::Profiles.get("svg_1_2_rfc")

      # Interleave validations
      results = []
      results << [:meta, validator.validate(svg_with_invalid_ref, profile: profile_meta).errors.count]
      results << [:rfc, validator.validate(svg_with_invalid_ref, profile: profile_rfc).errors.count]
      results << [:meta, validator.validate(svg_with_invalid_ref, profile: profile_meta).errors.count]
      results << [:rfc, validator.validate(svg_with_invalid_ref, profile: profile_rfc).errors.count]
      results << [:meta, validator.validate(svg_with_invalid_ref, profile: profile_meta).errors.count]

      # Extract counts by profile
      meta_counts = results.select { |type, _| type == :meta }.map(&:last)
      rfc_counts = results.select { |type, _| type == :rfc }.map(&:last)

      # Each profile should produce consistent results
      expect(meta_counts.uniq.size).to eq(1),
                                       "metanorma validations should be consistent: #{meta_counts.inspect}"
      expect(rfc_counts.uniq.size).to eq(1),
                                      "svg_1_2_rfc validations should be consistent: #{rfc_counts.inspect}"
    end
  end
end
