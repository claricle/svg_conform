# frozen_string_literal: true

require "spec_helper"
require "nokogiri"

RSpec.describe SvgConform::Profiles do
  let(:validator) { SvgConform::Validator.new(mode: :sax) }
  let(:profile) { described_class.get(:metanorma) }
  let(:plantuml_attributes) { %w[contentstyletype zoomandpan title textlength lengthadjust] }
  let(:svg) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
           version="1.2" baseProfile="tiny" viewBox="0 0 120 30"
           contentStyleType="text/css" zoomAndPan="magnify">
        <a xlink:href="https://example.test/UnitType" title="UnitType">
          <text id="label" x="0" y="12" textLength="100" lengthAdjust="spacing">UnitType</text>
        </a>
      </svg>
    SVG
  end

  it "accepts the five explicit layout and link attributes" do
    result = validator.validate(svg, profile: profile)
    expect(result.errors.map(&:message)).to be_empty
  end

  %w[svg text a].each do |element|
    it "still rejects unrelated attributes on #{element}" do
      invalid = svg.sub("<#{element} ", "<#{element} unsupported-plantuml-setting=\"no\" ")
      result = validator.validate(invalid, profile: profile)
      expect(result.errors.map(&:message).join).to include("unsupported-plantuml-setting")
    end
  end

  { "svg" => "textLength", "text" => "zoomAndPan", "a" => "lengthAdjust" }.each do |element, attribute|
    it "rejects #{attribute} on #{element}" do
      invalid = svg.sub("<#{element} ", "<#{element} #{attribute}=\"1\" ")
      result = validator.validate(invalid, profile: profile)
      expect(result.errors.map(&:message).join.downcase).to include("attribute '#{attribute.downcase}' is not allowed")
    end
  end

  %i[svg_1_2_rfc svg_1_2_rfc_with_rdf].each do |strict_profile|
    it "keeps #{strict_profile} attribute restrictions unchanged" do
      result = validator.validate(svg, profile: strict_profile)
      messages = result.errors.map(&:message).join.downcase
      plantuml_attributes.each do |attribute|
        expect(messages).to include("attribute '#{attribute}' is not allowed")
      end
    end
  end

  it "preserves native PlantUML text measurements and links during remediation" do
    source = File.read("spec/fixtures/plantuml/unit-type.svg")
    document = SvgConform::Document.from_content(source)
    result = validator.validate(source, profile: profile)
    SvgConform::RemediationEngine.new(profile).apply_remediations(document, result)
    output = document.root.to_xml
    errors = validator.validate(output, profile: profile).errors
      .reject { |error| error.violation_type == :reference_violation }

    # The fixture's fragment targets belong to the surrounding HTML document.
    expect(errors.map(&:message)).to be_empty
    expect(text_layout(output)).to eq(text_layout(source))
    expect(text_layout(output).size).to eq(28)
    expect(diagram_links(output)).to eq(diagram_links(source))
    expect(diagram_links(output).size).to eq(12)
  end

  def text_layout(xml)
    Nokogiri::XML(xml).xpath("//svg:text", "svg" => "http://www.w3.org/2000/svg").map do |node|
      [node.text, node["x"], node["y"], node["textLength"], node["lengthAdjust"]]
    end
  end

  def diagram_links(xml)
    Nokogiri::XML(xml).xpath("//svg:a", "svg" => "http://www.w3.org/2000/svg").map do |node|
      [node["title"], node.attribute_with_ns("href", "http://www.w3.org/1999/xlink")&.value]
    end
  end
end
