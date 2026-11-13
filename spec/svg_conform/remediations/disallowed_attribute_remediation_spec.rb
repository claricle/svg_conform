# frozen_string_literal: true

require "spec_helper"

RSpec.describe SvgConform::Remediations::DisallowedAttributeRemediation do
  # svg_1_2_rfc#88: Inkscape-authored documents carry enable-background
  # on the root svg element; the attribute is removed in SVG 1.2 RFC
  # (never rendered), so the remediation strips it wherever it rides.

  let(:remediation) do
    described_class.new(
      id: "enable_background_removal",
      description: "Remove enable-background",
      targets: ["allowed_elements"],
      attributes: ["enable-background"],
    )
  end

  let(:document) { SvgConform::Document.from_content(src) }

  context "with enable-background on the root svg element" do
    let(:src) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"
             enable-background="new 0 0 10 10">
          <rect width="5" height="5"/>
        </svg>
      SVG
    end

    it "removes the attribute" do
      changes = remediation.apply(document, nil)

      expect(changes.map { |c| c[:attribute] }).to eq(["enable-background"])
      expect(document.to_xml).not_to include("enable-background")
    end

    it "leaves every other attribute in place" do
      remediation.apply(document, nil)

      expect(document.to_xml).to include(%(width="10"))
      expect(document.to_xml).to include(%(height="10"))
    end
  end

  context "with enable-background on nested elements" do
    let(:src) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <g enable-background="new">
            <rect enable-background="new" width="5" height="5"/>
          </g>
        </svg>
      SVG
    end

    it "removes every occurrence" do
      changes = remediation.apply(document, nil)

      expect(changes.size).to eq(2)
      expect(document.to_xml).not_to include("enable-background")
    end
  end

  context "with the attribute absent" do
    let(:src) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
          <rect width="5" height="5"/>
        </svg>
      SVG
    end

    it "reports no changes" do
      expect(remediation.apply(document, nil)).to be_empty
    end
  end
end
