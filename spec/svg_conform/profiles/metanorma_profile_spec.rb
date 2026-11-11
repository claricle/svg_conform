# frozen_string_literal: true

require "spec_helper"

# Container elements take the clip-path and mask presentation attributes
# per SVG (metanorma-pdfa#106).
METANORMA_PROFILE_CONTAINER_TAGS = %w[g a defs].freeze
METANORMA_PROFILE_CLIP_ATTRIBUTES = %w[clip-path mask].freeze

RSpec.describe "Metanorma Profile" do
  let(:metanorma_sample_profile_path) { "config/profiles/metanorma-sample.yml" }

  describe "profile loading" do
    it "loads the Metanorma profile successfully" do
      profile = SvgConform::Profile.load_from_file(metanorma_sample_profile_path)
      expect(profile).not_to be_nil
      expect(profile.name).to eq("metanorma-sample")
    end

    it "includes external resource requirements" do
      profile = SvgConform::Profile.load_from_file(metanorma_sample_profile_path)
      requirement_ids = profile.requirements.map(&:id)
      expect(requirement_ids).to include("no_external_css")
      expect(requirement_ids).to include("no_external_fonts")
      expect(requirement_ids).to include("no_external_images")
    end

    it "includes comprehensive element support" do
      profile = SvgConform::Profile.load_from_file(metanorma_sample_profile_path)
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
      profile = SvgConform::Profile.load_from_file(metanorma_sample_profile_path)

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
      profile = SvgConform::Profile.load_from_file(metanorma_sample_profile_path)

      result = profile.validate(document)
      expect(result).to respond_to(:valid?)
    end
  end

  describe "clip-path and mask on container elements" do
    # SVG applies the clip-path and mask properties to container elements and
    # graphics elements alike; rejecting them on containers rejects
    # schema-valid documents (metanorma-pdfa#106).
    let(:profile) { SvgConform::Profile.load_from_file(metanorma_sample_profile_path) }
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

    METANORMA_PROFILE_CONTAINER_TAGS.each do |tag|
      METANORMA_PROFILE_CLIP_ATTRIBUTES.each do |attribute|
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

RSpec.describe "metanorma-sample marker presentation attributes" do
  let(:profile) do
    SvgConform::Profile.load_from_file("config/profiles/metanorma-sample.yml")
  end
  let(:validator) { SvgConform::Validator.new(mode: :sax, profile: profile) }

  def marker_svg(shape_attrs)
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" version="1.2" baseProfile="tiny" width="40" height="12" viewBox="0 0 40 12">
        <defs>
          <marker id="a" markerWidth="4" markerHeight="4" refX="2" refY="2" orient="auto">
            <path d="M0,0 L4,2 L0,4"/>
          </marker>
        </defs>
        <g>#{shape_attrs}</g>
      </svg>
    SVG
  end

  # claricle/svg_conform#128: the profile listed the marker element but
  # none of the marker presentation attributes on the shapes, so
  # marker-end="url(...)" failed while the same marker in a style
  # attribute passed.
  %w[path line polyline polygon].each do |tag|
    it "allows marker-end on #{tag}" do
      svg = marker_svg(
        %(<#{tag} #{tag == 'path' ? 'd="M2,6 H38"' : tag == 'line' ? 'x1="2" y1="6" x2="38" y2="6"' : 'points="2,6 20,6 38,6"'} marker-end="url(#a)"/>),
      )
      result = validator.validate(svg, profile: profile)
      attribute_errors = result.errors.select { |e| e.message.include?("marker-end") }
      expect(attribute_errors).to be_empty
    end

    it "allows marker-start and marker-mid on #{tag}" do
      svg = marker_svg(
        %(<#{tag} #{tag == 'path' ? 'd="M2,6 H38"' : tag == 'line' ? 'x1="2" y1="6" x2="38" y2="6"' : 'points="2,6 20,6 38,6"'} marker-start="url(#a)" marker-mid="url(#a)" marker-end="url(#a)"/>),
      )
      result = validator.validate(svg, profile: profile)
      attribute_errors = result.errors.select { |e| e.message.include?("marker") }
      expect(attribute_errors).to be_empty
    end
  end

  it "still rejects marker attributes on rect, where SVG does not define them" do
    svg = marker_svg(%(<rect x="2" y="2" width="36" height="8" marker-end="url(#a)"/>))
    result = validator.validate(svg, profile: profile)
    expect(result.errors.map(&:message).join).to include("marker-end")
  end
end
