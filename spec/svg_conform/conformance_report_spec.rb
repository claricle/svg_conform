# frozen_string_literal: true

require "spec_helper"

RSpec.describe SvgConform::ConformanceReport do
  let(:invalid_svg) { '<svg xmlns="http://www.w3.org/2000/svg"><rect width="5" height="5" fill="red"/></svg>' }
  let(:result) { SvgConform::Validator.new.validate(invalid_svg, profile: :svg_1_2_rfc) }

  describe ".from_svg_conform_result" do
    it "does not include info diagnostics in the legacy channels" do
      info = SvgConform::Validator.new.validate_file(
        File.expand_path("../fixtures/diagnostics/external-reference-info.svg", __dir__),
        profile: :svg_1_2_rfc,
      )
      report = described_class.from_svg_conform_result("i.svg", info)

      expect(report.valid).to be(true)
      expect(report.errors.total_count).to eq(0)
      expect(report.warnings.total_count).to eq(0)
    end

    it "still accepts use_svgcheck_mapping" do
      report = described_class.from_svg_conform_result("t.svg", result, profile: :svg_1_2_rfc,
                                                                        use_svgcheck_mapping: true)

      expect(report).to be_a(described_class)
    end

    context "with lens_core installed" do
      before do
        unless SvgConform.lens_core_available?
          skip "the optional lens_core gem is not installed"
        end
      end

      it "keeps its signature and legacy shape, projected from the canonical report" do
        report = described_class.from_svg_conform_result("t.svg", result, profile: :svg_1_2_rfc)
        canonical = result.to_lens_core_report

        expect(report.tool).to eq("svg_conform")
        expect(report.filename).to eq("t.svg")
        expect(report.valid).to eq(canonical.valid)
        expect(report.errors.total_count).to eq(canonical.summary["errors"])
        expect(report.warnings.total_count).to eq(canonical.summary["warnings"])
        expect(report.errors.issues.map(&:message))
          .to eq(canonical.diagnostics.select(&:error?).map(&:message))
        expect(report.errors.by_requirement.values.sum).to eq(report.errors.total_count)
        expect(report.to_yaml).to include("errors:", "total_count:", "by_requirement:")
      end

      it "does not mutate the canonical report" do
        before = result.to_lens_core_report.to_h
        described_class.from_svg_conform_result("t.svg", result, profile: :svg_1_2_rfc,
                                                                 use_svgcheck_mapping: true)

        expect(result.to_lens_core_report.to_h).to eq(before)
      end
    end

    context "without lens_core" do
      before do
        if SvgConform.lens_core_available?
          skip "lens_core is installed; the direct projection is not in effect"
        end
      end

      it "projects the validation result directly" do
        report = described_class.from_svg_conform_result("t.svg", result, profile: :svg_1_2_rfc)

        expect(report.tool).to eq("svg_conform")
        expect(report.filename).to eq("t.svg")
        expect(report.valid).to be(false)
        expect(report.errors.total_count).to eq(result.errors.length)
        expect(report.errors.by_requirement.values.sum).to eq(report.errors.total_count)
        expect(report.errors.issues.map(&:requirement_id).sort)
          .to eq(result.errors.map(&:requirement_id).sort)
        expect(report.to_yaml).to include("errors:", "total_count:", "by_requirement:")
      end
    end
  end

  describe ".from_svgcheck_result" do
    it "remains callable and reports valid for empty output" do
      report = described_class.from_svgcheck_result("t.svg", "")

      expect(report.tool).to eq("svgcheck")
      expect(report.valid).to be(true)
    end
  end
end
