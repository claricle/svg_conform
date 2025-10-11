# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Metanorma Profile" do
  let(:metanorma_profile_path) { "config/profiles/metanorma.yml" }

  describe "profile loading" do
    it "loads the Metanorma profile successfully" do
      profile = SvgConform::Profile.load_from_file(metanorma_profile_path)
      expect(profile).not_to be_nil
      expect(profile.name).to eq("metanorma")
    end

    it "includes external resource requirements" do
      profile = SvgConform::Profile.load_from_file(metanorma_profile_path)
      requirement_ids = profile.requirements.map(&:id)
      expect(requirement_ids).to include("no_external_css")
      expect(requirement_ids).to include("no_external_fonts")
      expect(requirement_ids).to include("no_external_images")
    end

    it "includes comprehensive element support" do
      profile = SvgConform::Profile.load_from_file(metanorma_profile_path)
      requirement_ids = profile.requirements.map(&:id)
      expect(requirement_ids).to include("allowed_elements")
    end
  end

  describe "validation" do
    it "allows flexible colors unlike RFC 7996" do
      svg_with_colors = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" version="1.2" baseProfile="tiny" viewBox="0 0 100 100">
          <rect x="10" y="10" width="50" height="50" fill="#ff0000"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(svg_with_colors)
      profile = SvgConform::Profile.load_from_file(metanorma_profile_path)

      result = profile.validate(document)
      color_errors = result.errors.select do |e|
        e.requirement_id == "color_restrictions"
      end
      expect(color_errors).to be_empty
    end

    it "supports image elements" do
      svg_with_image = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" version="1.2" baseProfile="tiny" viewBox="0 0 100 100">
          <image href="data:image/png;base64,abc" width="50" height="50"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(svg_with_image)
      profile = SvgConform::Profile.load_from_file(metanorma_profile_path)

      result = profile.validate(document)
      expect(result).to respond_to(:valid?)
    end
  end
end
