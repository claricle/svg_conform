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
      result_meta1 = validator.validate(svg_with_invalid_ref,
                                        profile: profile_meta)
      first_meta_count = result_meta1.errors.count

      # Validation with svg_1_2_rfc profile
      profile_rfc = SvgConform::Profiles.get("svg_1_2_rfc")
      result_rfc1 = validator.validate(svg_with_invalid_ref,
                                       profile: profile_rfc)
      first_rfc_count = result_rfc1.errors.count

      # Second validation with metanorma profile (should match first)
      result_meta2 = validator.validate(svg_with_invalid_ref,
                                        profile: profile_meta)
      second_meta_count = result_meta2.errors.count

      # Second validation with svg_1_2_rfc profile (should match first)
      result_rfc2 = validator.validate(svg_with_invalid_ref,
                                       profile: profile_rfc)
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
      results << [:meta,
                  validator.validate(svg_with_invalid_ref,
                                     profile: profile_meta).errors.count]
      results << [:rfc,
                  validator.validate(svg_with_invalid_ref,
                                     profile: profile_rfc).errors.count]
      results << [:meta,
                  validator.validate(svg_with_invalid_ref,
                                     profile: profile_meta).errors.count]
      results << [:rfc,
                  validator.validate(svg_with_invalid_ref,
                                     profile: profile_rfc).errors.count]
      results << [:meta,
                  validator.validate(svg_with_invalid_ref,
                                     profile: profile_meta).errors.count]

      # Extract counts by profile
      meta_counts = results.select { |k, _| k == :meta }.map(&:last)
      rfc_counts = results.select { |k, _| k == :rfc }.map(&:last)

      # Each profile should produce consistent results
      expect(meta_counts.uniq.size).to eq(1),
                                       "metanorma validations should be consistent: #{meta_counts.inspect}"
      expect(rfc_counts.uniq.size).to eq(1),
                                      "svg_1_2_rfc validations should be consistent: #{rfc_counts.inspect}"
    end

    it "returns different error counts for profiles with different requirements" do
      # Real-world SVG with style attributes that violate svg_1_2_rfc but not metanorma
      svg_with_styles = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" fill-rule="evenodd" preserveAspectRatio="xMidYMid" version="1.1" viewBox="0 0 28000 21000">
          <g class="Drawing" id="Straight_Connector_42">
            <g>
              <g style="stroke:rgb(0,0,0);stroke-width:88;fill:none">
                <path d="M 4264,13886 L 4264,17273" style="fill:none" />
          </g></g></g>
          <g class="Drawing" id="Straight_Connector_33">
            <g>
              <g style="stroke:rgb(0,0,0);stroke-width:88;fill:none">
                <path d="M 20355,10711 L 20351,13886" style="fill:none" />
          </g></g></g>
            <g class="Drawing">
              <g>
                <g style="stroke:none;fill:none">
                  <rect height="3490" width="25184" x="1512" y="340" />
                </g>
              <g style="font-family:Arial embedded;font-size:1552px;font-weight:400">
                <g style="stroke:none;fill:rgb(0,0,0)">
                  <text>
                    <tspan x="4733 5855 6718 7582 8446 8877 9741 10605 11036 12074 12853 13716 14580 15443 15960 16307 17171 17602 18724 19071 19935 20799 21315 22179 " y="2482">
                      Updated Scenario Diagram
                    </tspan>
                  </text>
                </g>
              </g>
              </g>
            </g>
        </svg>
      SVG

      validator = SvgConform::Validator.new(mode: :sax)

      # Validate with metanorma (should have 0 errors - more permissive)
      profile_meta = SvgConform::Profiles.get("metanorma")
      result_meta = validator.validate(svg_with_styles, profile: profile_meta)
      meta_errors = result_meta.errors.count

      # Validate with svg_1_2_rfc (should have errors - stricter requirements)
      profile_rfc = SvgConform::Profiles.get("svg_1_2_rfc")
      result_rfc = validator.validate(svg_with_styles, profile: profile_rfc)
      rfc_errors = result_rfc.errors.count

      # Profiles should return different results
      expect(meta_errors).to eq(0), "metanorma profile should allow this SVG"
      expect(rfc_errors).to be > 0,
                            "svg_1_2_rfc profile should detect violations"

      # Verify consistency when repeating
      result_rfc2 = validator.validate(svg_with_styles, profile: profile_rfc)
      expect(result_rfc2.errors.count).to eq(rfc_errors),
                                          "svg_1_2_rfc should return same error count on repeat (no state leakage)"
    end
  end
end
