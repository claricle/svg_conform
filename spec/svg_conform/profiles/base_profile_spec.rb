# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Base Profile" do
  let(:base_profile_path) { "config/profiles/base.yml" }

  describe "profile loading" do
    it "loads the base profile successfully" do
      profile = SvgConform::Profile.load_from_file(base_profile_path)
      expect(profile).not_to be_nil
      expect(profile.name).to eq("base")
    end

    it "has minimal requirements" do
      profile = SvgConform::Profile.load_from_file(base_profile_path)
      expect(profile.requirements).to be_an(Array)
    end

    it "serves as a foundation for other profiles" do
      profile = SvgConform::Profile.load_from_file(base_profile_path)
      expect(profile.description).to be_a(String)
    end
  end

  describe "validation" do
    it "can validate a simple SVG document" do
      svg_content = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <rect x="10" y="10" width="50" height="50" fill="red"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(svg_content)
      profile = SvgConform::Profile.load_from_file(base_profile_path)

      result = profile.validate(document)
      expect(result).to respond_to(:valid?)
      expect(result).to respond_to(:errors)
    end
  end
end
