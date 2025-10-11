# frozen_string_literal: true

require "spec_helper"

RSpec.describe "No External CSS Profile" do
  let(:no_external_css_profile_path) { "config/profiles/no_external_css.yml" }

  describe "profile loading" do
    it "loads the no external css profile successfully" do
      profile = SvgConform::Profile.load_from_file(no_external_css_profile_path)
      expect(profile).not_to be_nil
      expect(profile.name).to eq("no_external_css")
    end

    it "includes no_external_css requirement" do
      profile = SvgConform::Profile.load_from_file(no_external_css_profile_path)
      requirement_ids = profile.requirements.map(&:id)
      expect(requirement_ids).to include("no_external_css")
    end

    it "has description indicating external CSS restriction" do
      profile = SvgConform::Profile.load_from_file(no_external_css_profile_path)
      expect(profile.description).to be_a(String)
      expect(profile.description.downcase).to match(/external.*css/)
    end
  end

  describe "validation" do
    it "rejects SVG with external CSS references" do
      svg_with_external_css = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <defs>
            <style>
              @import url("external.css");
            </style>
          </defs>
          <rect x="10" y="10" width="50" height="50"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(svg_with_external_css)
      profile = SvgConform::Profile.load_from_file(no_external_css_profile_path)

      result = profile.validate(document)
      expect(result.valid?).to be false
      expect(result.errors.map(&:requirement_id)).to include("no_external_css")
    end

    it "accepts SVG with inline styles" do
      svg_with_inline_styles = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <rect x="10" y="10" width="50" height="50" style="fill:red"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(svg_with_inline_styles)
      profile = SvgConform::Profile.load_from_file(no_external_css_profile_path)

      result = profile.validate(document)
      external_css_errors = result.errors.select do |e|
        e.requirement_id == "no_external_css"
      end
      expect(external_css_errors).to be_empty
    end
  end
end
