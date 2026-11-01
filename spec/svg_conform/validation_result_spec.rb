# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe SvgConform::ValidationResult do
  let(:fixture) { File.expand_path("../fixtures/diagnostics/external-reference-info.svg", __dir__) }
  let(:invalid_svg) { '<svg xmlns="http://www.w3.org/2000/svg"><rect width="5" height="5" fill="red"/></svg>' }
  let(:info_result) { SvgConform::Validator.new.validate_file(fixture, profile: :svg_1_2_rfc) }
  let(:invalid_result) { SvgConform::Validator.new.validate(invalid_svg, profile: :svg_1_2_rfc) }

  it "exposes infos and info_count without affecting validity" do
    expect(info_result.infos.size).to eq(1)
    expect(info_result.info_count).to eq(1)
    expect(info_result).to be_valid
  end

  it "counts validity errors as errors and keeps valid? tied to them" do
    context = SvgConform::ValidationContext.new(nil, SvgConform::Profile.new(name: "p"))
    context.add_error(node: nil, message: "v", requirement_id: "r", severity: :validity_error)
    result = described_class.new(nil, SvgConform::Profile.new(name: "p"), context)

    expect(result.error_count).to eq(1)
    expect(result).not_to be_valid
  end

  context "with lens_core installed" do
    before do
      unless SvgConform.lens_core_available?
        skip "the optional lens_core gem is not installed"
      end
    end

    it "builds the canonical report with an optional timestamp" do
      report = info_result.to_lens_core_report(timestamp: "2026-10-23T01:02:03Z")

      expect(report.summary["infos"]).to eq(1)
      expect(report.to_h["timestamp"]).to eq("2026-10-23T01:02:03Z")
    end

    it "counts validity errors in the canonical report" do
      context = SvgConform::ValidationContext.new(nil, SvgConform::Profile.new(name: "p"))
      context.add_error(node: nil, message: "v", requirement_id: "r", severity: :validity_error)
      result = described_class.new(nil, SvgConform::Profile.new(name: "p"), context)

      expect(result.to_lens_core_report.summary["errors"]).to eq(1)
    end

    it "projects to_json from the canonical report plus compatibility extensions" do
      parsed = JSON.parse(info_result.to_json)
      canonical = info_result.to_lens_core_report.to_h

      expect(parsed).to include(canonical.except("file"))
      expect(parsed.keys).to include("fixes_applied", "fixable", "reference_manifest")
      expect(LensCore::Parsers::Json.parse(info_result.to_json).summary["infos"]).to eq(1)
      expect(info_result.to_s(format: :json)).to eq(info_result.to_json)
    end

    it "keeps to_h callable with symbol keys" do
      hash = info_result.to_h

      expect(hash[:valid]).to be(true)
      expect(hash[:reference_manifest]).to have_key(:available_ids)
      expect(hash[:diagnostics].first[:severity]).to eq("info")
    end

    it "renders text from the human renderer and includes the info" do
      text = info_result.to_s

      expect(text).to include("VALID: 0 errors, 0 warnings, 1 info")
      expect(text).to include("info  link_validation")
      expect(invalid_result.to_s).to include("INVALID")
    end

    it "renders YAML from the canonical report" do
      expect(LensCore::Parsers::Yaml.parse(info_result.to_yaml).summary["infos"]).to eq(1)
    end
  end

  context "without lens_core" do
    before do
      if SvgConform.lens_core_available?
        skip "lens_core is installed; the plain serializers are not in effect"
      end
    end

    it "raises a clear error from to_lens_core_report" do
      expect { info_result.to_lens_core_report }
        .to raise_error(SvgConform::Error, /lens_core is not installed/)
    end

    it "serializes the plain structural shape as JSON" do
      parsed = JSON.parse(info_result.to_json)

      expect(parsed).to include("file", "profile", "valid", "errors", "warnings")
      expect(parsed["valid"]).to be(true)
      expect(parsed["errors"]).to eq([])
    end

    it "keeps to_h callable with symbol keys" do
      hash = info_result.to_h

      expect(hash[:valid]).to be(true)
      expect(hash[:reference_manifest]).to have_key(:available_ids)
      expect(hash).to have_key(:errors)
    end

    it "renders the plain text report" do
      text = info_result.to_s

      expect(text).to include("SVG Conformance Report")
      expect(text).to include("Status: VALID")
      expect(text).to include("✓ Document is valid")
      expect(invalid_result.to_s).to include("Status: INVALID")
    end

    it "renders YAML from the structural shape" do
      parsed = YAML.safe_load(info_result.to_yaml)

      expect(parsed["valid"]).to be(true)
    end
  end
end
