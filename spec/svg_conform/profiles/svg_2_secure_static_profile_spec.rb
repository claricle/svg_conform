# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SVG 2 secure-static profile" do
  let(:profile) { SvgConform::Profiles.get("svg_2_secure_static") }
  let(:citation) do
    "https://www.w3.org/TR/2026/CR-SVG2-20261006/conform.html#secure-static-mode"
  end
  let(:root) { "spec/fixtures/profiles/svg_2_secure_static" }

  def dom_report(path)
    profile.validate(SvgConform::Document.from_file(path))
  end

  def sax_report(path)
    SvgConform::SaxDocument.from_file(path).validate_with_profile(profile)
  end

  def summary(result)
    result.errors.map do |e|
      [e.requirement_id, e.data[:citation]]
    end.sort
  end

  it "is discoverable, opt-in and dated" do
    expect(SvgConform::Profiles.list).to include("svg_2_secure_static")
    expect(profile.specification_uri).to include("CR-SVG2-20261006")
    default = SvgConform::Cli.commands["check"].options[:profile].default
    expect(default).to eq("svg_1_2_rfc")
  end

  it "defines the four stable requirement ids with the dated citation" do
    categories = profile.requirements.first.categories
    ids = categories.map(&:id) + [profile.requirements.last.id]
    expect(ids).to eq(%w[svg2.secure_static.script svg2.secure_static.animation
                         svg2.secure_static.interaction
                         svg2.secure_static.external_reference])
    expect(categories.map(&:citation).uniq).to eq([citation])
    expect(profile.requirements.last.citation_uri).to eq(citation)
  end

  it "uses the unchanged Card 03 requirement class and shape" do
    expect(profile.requirements.first)
      .to be_a(SvgConform::Requirements::ProcessingFeaturesRequirement)
    expect(profile.requirements.first.categories.first.class.attributes.keys)
      .to eq(%i[name id citation description elements attributes
                attribute_patterns])
  end

  Dir.glob("spec/fixtures/profiles/svg_2_secure_static/valid/*.svg").each do |path|
    it "accepts #{File.basename(path)} through DOM and SAX" do
      expect(dom_report(path).errors).to be_empty
      expect(sax_report(path).errors).to be_empty
    end
  end

  {
    "script" => "svg2.secure_static.script",
    "animation" => "svg2.secure_static.animation",
    "interaction" => "svg2.secure_static.interaction",
  }.each do |name, id|
    it "rejects #{name}.svg only with #{id}, matching DOM and SAX" do
      path = "#{root}/invalid/#{name}.svg"
      expect(dom_report(path).errors.map(&:requirement_id).uniq).to eq([id])
      expect(summary(sax_report(path))).to eq(summary(dom_report(path)))
      expect(summary(sax_report(path)).first.last).to eq(citation)
    end
  end

  def self.external_fixtures
    Dir.glob("spec/fixtures/profiles/svg_2_secure_static/invalid/*.svg")
      .map { |f| File.basename(f, ".svg") } - %w[script animation interaction]
  end

  it "enumerates the external-reference corpus" do
    expect(self.class.external_fixtures.size).to eq(18)
  end

  external_fixtures.each do |name|
    it "rejects #{name}.svg with external_reference, matching DOM and SAX" do
      path = "#{root}/invalid/#{name}.svg"
      expect(dom_report(path).errors.map(&:requirement_id).uniq)
        .to eq(["svg2.secure_static.external_reference"])
      expect(summary(sax_report(path))).to eq(summary(dom_report(path)))
      expect(dom_report(path).errors.first.data[:citation]).to eq(citation)
    end
  end

  it "emits a LensCore report with the profile citation" do
    report = SvgConform::Diagnostics::LensCoreAdapter.call(
      sax_report("#{root}/invalid/http.svg"),
    )
    expect(report.valid).to be false
    expect(report.profile.id).to eq("svg_2_secure_static")
  end
end
