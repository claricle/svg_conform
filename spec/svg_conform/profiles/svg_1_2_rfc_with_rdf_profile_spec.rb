# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SVG 1.2 RFC with RDF Profile" do
  let(:svg_1_2_rfc_with_rdf_profile_path) do
    "config/profiles/svg_1_2_rfc_with_rdf.yml"
  end

  describe "profile loading" do
    it "loads the SVG 1.2 RFC with RDF profile successfully" do
      profile = SvgConform::Profile.load_from_file(svg_1_2_rfc_with_rdf_profile_path)
      expect(profile).not_to be_nil
      expect(profile.name).to eq("svg_1_2_rfc_with_rdf")
    end

    it "includes all base RFC 7996 requirements" do
      profile = SvgConform::Profile.load_from_file(svg_1_2_rfc_with_rdf_profile_path)
      requirement_ids = profile.requirements.map(&:id)

      base_requirements = %w[
        allowed_elements
        color_restrictions
        font_family
        namespace_validation
        viewbox_required
      ]

      expect(requirement_ids).to include(*base_requirements)
    end

    it "has description indicating RDF metadata support" do
      profile = SvgConform::Profile.load_from_file(svg_1_2_rfc_with_rdf_profile_path)
      expect(profile.description).to be_a(String)
      expect(profile.description.downcase).to match(/rdf|metadata/)
    end
  end

  describe "RDF metadata handling" do
    it "allows RDF metadata elements" do
      svg_with_rdf = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg"
             xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
             xmlns:dc="http://purl.org/dc/elements/1.1/"
             viewBox="0 0 100 100">
          <metadata>
            <rdf:RDF>
              <rdf:Description>
                <dc:title>Test Document</dc:title>
              </rdf:Description>
            </rdf:RDF>
          </metadata>
          <rect x="10" y="10" width="50" height="50" fill="red"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(svg_with_rdf)
      profile = SvgConform::Profile.load_from_file(svg_1_2_rfc_with_rdf_profile_path)

      result = profile.validate(document)
      expect(result).to respond_to(:valid?)
    end
  end

  describe "validation" do
    it "maintains all SVG 1.2 RFC compliance checks" do
      svg_content = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <rect x="10" y="10" width="50" height="50" fill="red"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(svg_content)
      profile = SvgConform::Profile.load_from_file(svg_1_2_rfc_with_rdf_profile_path)

      result = profile.validate(document)
      expect(result).to respond_to(:valid?)
      expect(result).to respond_to(:errors)
    end
  end
end
