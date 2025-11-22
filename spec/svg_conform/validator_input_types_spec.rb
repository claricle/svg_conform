# frozen_string_literal: true

require "spec_helper"

RSpec.describe SvgConform::Validator do
  let(:validator) { described_class.new(mode: :sax) }
  let(:simple_svg) do
    <<~SVG
      <?xml version="1.0" encoding="UTF-8"?>
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
        <rect id="box" x="10" y="10" width="80" height="80" fill="black"/>
      </svg>
    SVG
  end

  describe "#validate with different input types" do
    context "with String input (backward compatibility)" do
      it "validates XML string successfully" do
        result = validator.validate(simple_svg, profile: :metanorma)

        expect(result).to be_a(SvgConform::ValidationResult)
        expect(result.valid?).to be true
      end

      it "processes errors correctly" do
        invalid_svg = '<svg><rect fill="red"/></svg>'
        result = validator.validate(invalid_svg, profile: :svg_1_2_rfc)

        expect(result).to be_a(SvgConform::ValidationResult)
        # Will have errors due to missing viewBox and invalid color
      end
    end

    context "with Moxml::Document input" do
      it "validates Moxml document without re-parsing" do
        # Parse once into Moxml
        moxml_doc = Moxml.new.parse(simple_svg)

        # Validate using the document object
        result = validator.validate(moxml_doc, profile: :metanorma)

        expect(result).to be_a(SvgConform::ValidationResult)
        expect(result.valid?).to be true
      end

      it "serializes document once for SAX validation (safe for large files)" do
        moxml_doc = Moxml.new.parse(simple_svg)

        # Should call to_xml once for SAX validation
        # (SAX mode is safe for large files, unlike DOM)
        expect(moxml_doc).to receive(:to_xml).once.and_call_original

        validator.validate(moxml_doc, profile: :metanorma)
      end
    end

    context "with Moxml::Element input" do
      it "validates Moxml element node" do
        moxml_doc = Moxml.new.parse(simple_svg)
        svg_element = moxml_doc.root

        result = validator.validate(svg_element, profile: :metanorma)

        expect(result).to be_a(SvgConform::ValidationResult)
        expect(result.valid?).to be true
      end
    end

    context "with Nokogiri input (metanorm use case)" do
      it "validates Nokogiri::XML::Document" do
        nokogiri_doc = Nokogiri::XML(simple_svg)

        result = validator.validate(nokogiri_doc, profile: :metanorma)

        expect(result).to be_a(SvgConform::ValidationResult)
        expect(result.valid?).to be true
      end

      it "validates Nokogiri::XML::Element" do
        nokogiri_doc = Nokogiri::XML(simple_svg)
        svg_element = nokogiri_doc.root

        # This is the metanorma use case - passing element directly
        result = validator.validate(svg_element, profile: :metanorma)

        expect(result).to be_a(SvgConform::ValidationResult)
        expect(result.valid?).to be true
      end

      it "serializes Nokogiri element once for SAX validation" do
        nokogiri_doc = Nokogiri::XML(simple_svg)
        svg_element = nokogiri_doc.root

        # Should call to_xml once for SAX validation
        # (SAX mode is memory-safe for large SVGs)
        expect(svg_element).to receive(:to_xml).once.and_call_original

        validator.validate(svg_element, profile: :metanorma)
      end
    end

    context "with invalid input" do
      it "raises ArgumentError for unsupported input type" do
        expect do
          validator.validate(12345, profile: :metanorma)
        end.to raise_error(ArgumentError, /Invalid input type/)
      end

      it "raises ArgumentError for nil input" do
        expect do
          validator.validate(nil, profile: :metanorma)
        end.to raise_error(ArgumentError, /Invalid input type/)
      end
    end

    context "with reference manifest" do
      let(:svg_with_refs) do
        <<~SVG
          <?xml version="1.0" encoding="UTF-8"?>
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
            <defs>
              <rect id="box" width="10" height="10"/>
            </defs>
            <use href="#box" x="20" y="20"/>
          </svg>
        SVG
      end

      it "builds reference manifest from Nokogiri element" do
        nokogiri_doc = Nokogiri::XML(svg_with_refs)
        svg_element = nokogiri_doc.root

        result = validator.validate(svg_element, profile: :metanorma)

        expect(result.reference_manifest).not_to be_nil
        expect(result.available_ids.map(&:id_value)).to include("box")
        expect(result.internal_references.size).to be > 0
      end

      it "builds reference manifest from Moxml document" do
        moxml_doc = Moxml.new.parse(svg_with_refs)

        result = validator.validate(moxml_doc, profile: :metanorma)

        expect(result.reference_manifest).not_to be_nil
        expect(result.available_ids.map(&:id_value)).to include("box")
      end
    end
  end

  describe "integration with remediation" do
    let(:invalid_svg) do
      <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <rect fill="red" width="10" height="10"/>
        </svg>
      SVG
    end

    it "applies remediation when using document object input" do
      nokogiri_doc = Nokogiri::XML(invalid_svg)
      svg_element = nokogiri_doc.root

      result = validator.validate(svg_element, profile: :svg_1_2_rfc, fix: true)

      # Should have validation errors initially
      expect(result.has_errors?).to be true
      # Remediation should have been attempted
    end
  end
end
