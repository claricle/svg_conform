# frozen_string_literal: true

require "spec_helper"

RSpec.describe SvgConform::Diagnostics::LensCoreAdapter do
  let(:requirement) do
    SvgConform::Requirements::ViewboxRequiredRequirement.new(
      id: "viewbox_required", description: "d",
      citation_uri: "https://example.com/spec#viewbox",
      citation_label: "Spec viewBox"
    )
  end
  let(:profile) do
    SvgConform::Profile.new(
      name: "demo", specification_uri: "https://example.com/spec",
      specification_label: "Demo Spec", requirements: [requirement]
    )
  end
  let(:node) { Struct.new(:line, :column, :name).new(3, 5, "svg") }
  let(:context) { SvgConform::ValidationContext.new(nil, profile) }
  let(:result) { SvgConform::ValidationResult.new(nil, profile, context) }

  def add_all(data: {})
    context.add_error(node: node, message: "bad error", requirement_id: "viewbox_required",
                      data: data)
    context.add_error(node: node, message: "bad validity", requirement_id: "id_reference",
                      severity: :validity_error)
    context.add_warning(rule: Struct.new(:id).new("warn_rule"), node: node, message: "a warning")
    context.add_notice(rule: nil, node: node, message: "an info", requirement_id: "some_notice")
  end

  describe ".call" do
    it "maps all four channels to one schema-valid report in channel order" do
      add_all
      report = described_class.call(result, filename: "f.svg")

      expect(report).to be_a(LensCore::Report)
      expect(report.valid).to be(false)
      expect(report.summary).to eq("errors" => 2, "warnings" => 1, "infos" => 1)
      expect(report.diagnostics.map { |d| [d.severity, d.requirement_id] }).to eq(
        [%w[error viewbox_required], %w[error id_reference],
         %w[warning warn_rule], %w[info some_notice]],
      )
      expect(report.diagnostics[1].kind).to eq("validity")
      expect(report.diagnostics[3].kind).to eq("notice")
      expect(report.extensions["file"]).to eq("f.svg")

      reparsed = LensCore::Parsers::Json.parse(LensCore::Renderers::Json.render(report))
      expect(reparsed).to eq(report)
    end

    it "keeps validity based on errors and validity errors only" do
      context.add_warning(rule: "w", node: node, message: "w")
      context.add_notice(rule: nil, node: node, message: "i", requirement_id: "x")

      expect(described_class.call(result).valid).to be(true)
    end

    it "carries location, remediation fields and explicit IDs" do
      add_all
      error = described_class.call(result).diagnostics.first

      expect(error.location.line).to eq(3)
      expect(error.location.column).to eq(5)
      expect(error.remediation).to eq("Add missing viewBox attribute")
      expect(error.context).to include("element" => "svg", "fixable" => false,
                                       "remediation_type" => "add")
    end

    it "maps source-level line and column data to an XML location" do
      context.add_error(node: nil, message: "css", requirement_id: "viewbox_required",
                        data: { line: 7, column: 2 })
      context.add_error(node: nil, message: "bad", requirement_id: "viewbox_required",
                        data: { line: 0, column: "x" })
      context.add_error(node: node, message: "node", requirement_id: "viewbox_required",
                        data: { line: 99 })
      first, second, third = described_class.call(result).diagnostics

      expect(first.location.to_h).to include("line" => 7, "column" => 2)
      expect(second.location).to be_nil
      expect(third.location.line).to eq(3)
    end

    it "turns profile and requirement citations into LensCore citations" do
      add_all
      report = described_class.call(result)

      expect(report.profile.citations.map(&:to_h)).to eq(
        [{ "uri" => "https://example.com/spec", "label" => "Demo Spec" }],
      )
      expect(report.diagnostics.first.citations.map(&:uri)).to eq(["https://example.com/spec#viewbox"])
      expect(report.diagnostics[2].citations).to eq([])
    end

    it "only includes a timestamp when supplied" do
      add_all
      expect(described_class.call(result).timestamp).to be_nil
      expect(described_class.call(result, timestamp: "2026-10-23T00:00:00Z").to_h["timestamp"])
        .to eq("2026-10-23T00:00:00Z")
    end

    it "normalizes symbols in issue data to JSON primitives" do
      add_all(data: { attribute: :fill, nested: [1, { ok: true }] })
      data = described_class.call(result).diagnostics.first.context["data"]

      expect(data).to eq("attribute" => "fill", "nested" => [1, { "ok" => true }])
    end

    it "fails deterministically for JSON-unsafe issue data" do
      add_all(data: { thing: Object.new })

      expect { described_class.call(result) }
        .to raise_error(SvgConform::Diagnostics::UnsupportedContextError,
                        /unsupported value of type Object at data\.thing/)
    end
  end

  describe "profile loading" do
    it "keeps citations through YAML loading" do
      loaded = SvgConform::Profile.from_yaml(<<~YAML)
        name: yaml_demo
        specification_uri: https://example.com/s
        specification_label: S
        requirements:
          - id: viewbox_required
            type: ViewboxRequiredRequirement
            citation_uri: https://example.com/s#v
            citation_label: V
      YAML

      expect(loaded.specification_uri).to eq("https://example.com/s")
      expect(loaded.get_requirement("viewbox_required").citation_uri).to eq("https://example.com/s#v")
      expect(loaded.get_requirement("viewbox_required").citation_label).to eq("V")
    end
  end
end
