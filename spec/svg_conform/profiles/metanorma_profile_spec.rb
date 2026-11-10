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

  describe "clip-path and mask on container elements" do
    # SVG applies the clip-path and mask properties to container elements and
    # graphics elements alike; rejecting them on containers rejects
    # schema-valid documents (metanorma-pdfa#106).
    let(:profile) { SvgConform::Profile.load_from_file(metanorma_profile_path) }
    let(:validator) { SvgConform::Validator.new(mode: :sax) }

    def svg_with_clip_assets(inner)
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" version="1.2" baseProfile="tiny" viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip1">
              <rect x="0" y="0" width="50" height="50"/>
            </clipPath>
            <mask id="mask1">
              <rect x="0" y="0" width="50" height="50" fill="white"/>
            </mask>
          </defs>
          #{inner}
        </svg>
      SVG
    end

    %w[g a defs].each do |tag|
      %w[clip-path mask].each do |attribute|
        it "allows #{attribute} on #{tag}" do
          svg = svg_with_clip_assets(
            "<#{tag} #{attribute}=\"url(##{attribute == 'clip-path' ? 'clip1' : 'mask1'})\">" \
            "<rect x=\"10\" y=\"10\" width=\"30\" height=\"30\" fill=\"red\"/>" \
            "</#{tag}>",
          )

          result = validator.validate(svg, profile: profile)
          attribute_errors = result.errors.select do |e|
            e.message.include?("'#{attribute}'")
          end
          expect(attribute_errors).to be_empty
          expect(result).to be_valid
        end
      end
    end
  end
end
