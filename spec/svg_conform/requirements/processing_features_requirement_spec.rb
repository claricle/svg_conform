# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe SvgConform::Requirements::ProcessingFeaturesRequirement do
  let(:config_path) { "config/requirements/processing_features_static.yml" }
  let(:requirement) { described_class.from_yaml(File.read(config_path)) }
  let(:profile) do
    SvgConform::Profile.new(name: "pf", requirements: [requirement])
  end
  let(:svg_ns) { 'xmlns="http://www.w3.org/2000/svg"' }

  def svg(body)
    %(<svg #{svg_ns} version="1.1" viewBox="0 0 10 10">#{body}</svg>)
  end

  def dom_ids(xml)
    profile.validate(SvgConform::Document.from_content(xml))
      .errors.map(&:requirement_id).sort
  end

  def sax_ids(xml)
    SvgConform::SaxDocument.from_content(xml).validate_with_profile(profile)
      .errors.map(&:requirement_id).sort
  end

  it "loads the three categories from YAML with separate ids and citations" do
    expect(requirement.categories.map(&:name))
      .to eq(%w[script animation interaction])
    expect(requirement.categories.map(&:id)).to eq(
      %w[svg11.processing.script svg11.processing.animation
         svg11.processing.interaction],
    )
    expect(requirement.categories.map(&:citation).uniq.size).to eq(1)
  end

  it "resolves through a profile YAML via the requirement class map" do
    entry = File.read(config_path).lines.each_with_index.map do |l, i|
      i.zero? ? "  - #{l}" : "    #{l}"
    end.join
    yaml = "name: x\nrequirements:\n#{entry}"
    loaded = SvgConform::Profile.from_yaml(yaml)
    expect(loaded.requirements.first).to be_a(described_class)
  end

  it "is registered in Requirements.all" do
    expect(SvgConform::Requirements.all).to include(described_class)
  end

  {
    "script element" => ["<script>x()</script>", %w[svg11.processing.script]],
    "load handler" => ['<rect onload="x()" width="1" height="1"/>',
                       %w[svg11.processing.script]],
    "animate element" => ['<rect width="1" height="1"><animate attributeName="x" dur="1s"/></rect>',
                          %w[svg11.processing.animation svg11.processing.animation]],
    "click handler" => ['<rect onclick="x()" width="1" height="1"/>',
                        %w[svg11.processing.interaction]],
    "cursor attribute" => ['<rect cursor="pointer" width="1" height="1"/>',
                           %w[svg11.processing.interaction]],
    "clean static" => ['<rect width="1" height="1"/>', []],
  }.each do |label, (body, expected)|
    it "reports #{label} identically through DOM and SAX" do
      xml = svg(body)
      expect(dom_ids(xml)).to eq(expected)
      expect(sax_ids(xml)).to eq(expected)
    end
  end

  it "attaches the category citation to the error" do
    error = SvgConform::SaxDocument.from_content(svg("<script/>"))
      .validate_with_profile(profile).errors.first
    expect(error.data[:citation]).to eq(requirement.categories.first.citation)
  end
end
