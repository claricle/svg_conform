# frozen_string_literal: true

require "spec_helper"
require "digest"
require "yaml"
require "tmpdir"
require "svg_conform/validation/svg_1_1_document_conformance"

# Path is fixed by the card; the cop expects svg11_ instead of svg_1_1_.
RSpec.describe SvgConform::Validation::Svg11DocumentConformance do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:conformance) { described_class.new }

  let(:ns) { %(xmlns="http://www.w3.org/2000/svg" version="1.1") }
  let(:dtd_path) { described_class::DTD_PATH }

  def svg(body, attrs = ns)
    %(<?xml version="1.0"?>\n<svg #{attrs}>#{body}</svg>)
  end

  # Library selection record (card 03, "Open implementation question").
  # Probes: valid document, invalid content model, external-entity attempt,
  # Appendix G.2 foreign content, run offline against the vendored flat DTD.
  #
  #   Moxml/Leptris 1.9.381 (Leptris::XML::DTD): parses the DTD but ignores
  #   conditional sections whose keyword is a parameter entity
  #   (<![%svg-structure.module;[ ... ]]>), so no SVG element is declared and
  #   every probe, including the invalid ones, reports valid. Rejected.
  #   Nokogiri 1.19 (libxml2 2.13, Ruby >= 3.1 with 1.16/1.18): all four
  #   probes behave correctly offline, in-process, with NONET and no entity
  #   loading. Selected.
  describe "library probes" do
    let(:flat_dtd) { File.read(dtd_path) }

    it "records that Leptris cannot enforce the flat DTD" do
      require "leptris"
      handle = Leptris::XML::DTD.parse(flat_dtd)
      invalid = Leptris::XML.parse(%(<svg #{ns}><rect width="1" height="1"><g/></rect></svg>))

      expect(handle.validate(invalid)).to be_empty
    end

    it "probe 1: Nokogiri accepts a valid document" do
      expect(conformance.validate(svg(%(<rect width="1" height="1"/>))).issues).to be_empty
    end

    it "probe 2: Nokogiri rejects an invalid content model" do
      result = conformance.validate(svg(%(<rect width="1" height="1"><g/></rect>)))

      expect(result.issues.map(&:kind)).to eq([:dtd])
      expect(result.issues.first.message).to include("rect content does not follow the DTD")
    end

    it "probe 3: an external entity attempt is rejected without reading the file" do
      Dir.mktmpdir do |dir|
        secret = File.join(dir, "secret.txt")
        File.write(secret, "SECRET-MARKER")
        source = %(<?xml version="1.0"?><!DOCTYPE svg [<!ENTITY x SYSTEM "file://#{secret}">]>) +
          %(<svg #{ns}><title>&x;</title></svg>)

        result = conformance.validate(source)

        expect(result.issues.map(&:kind)).to eq([:external_entity])
        expect(result.transformed).to be_nil
      end
    end

    it "probe 4: foreign content validates after the Appendix G.2 transform" do
      source = svg(%(<f:thing f:a="1"><g/></f:thing><metadata><f:m/></metadata>),
                   %(#{ns} xmlns:f="urn:foreign"))

      expect(conformance.validate(source).issues).to be_empty
    end
  end

  describe "#validate" do
    it "reports a missing required attribute" do
      result = conformance.validate(svg(%(<rect height="1"/>)))

      expect(result.issues.first.message).to include("Element rect does not carry attribute width")
    end

    it "reports an undeclared attribute" do
      result = conformance.validate(svg(%(<rect width="1" height="1" bogus="x"/>)))

      expect(result.issues.first.message).to include("No declaration for attribute bogus")
    end

    it "reports malformed XML" do
      result = conformance.validate(svg(%(<rect width="1" height="1">)))

      expect(result.issues.first.kind).to eq(:malformed_xml)
    end

    it "reports a document element outside the SVG namespace" do
      result = conformance.validate(%(<svg xmlns="urn:other" version="1.1"/>))

      expect(result.issues.map(&:kind)).to eq([:no_svg_root])
    end

    it "validates xlink attributes under any prefix" do
      source = svg(%(<defs><g id="a"/></defs><use xlink:href="#a"/>),
                   %(#{ns} xmlns:xl="http://www.w3.org/1999/xlink"))
      source = source.sub("xlink:href", "xl:href")

      expect(conformance.validate(source).issues).to be_empty
    end

    it "validates prefixed SVG elements" do
      source = %(<s:svg xmlns:s="http://www.w3.org/2000/svg" version="1.1"><s:rect width="1" height="1"/></s:svg>)

      expect(conformance.validate(source).issues).to be_empty
    end

    it "expands internal entities before validating" do
      source = %(<?xml version="1.0"?><!DOCTYPE svg [<!ENTITY w "5">]><svg #{ns}><rect width="&w;" height="1"/></svg>)

      expect(conformance.validate(source).issues).to be_empty
    end

    it "never modifies the caller's source" do
      source = svg(%(<f:x xmlns:f="urn:f"/><rect width="1" height="1"/>)).freeze

      expect { conformance.validate(source) }.not_to raise_error
      expect(source).to include("<f:x")
    end

    it "keeps the Appendix G.2 copy free of foreign content" do
      copy = conformance.validate(svg(%(<f:x xmlns:f="urn:f"/>), %(#{ns} f2:a="1" xmlns:f2="urn:f"))).transformed

      expect(copy).not_to include("f:x")
      expect(copy).not_to include("f2:a")
      expect(copy).to include(%(xmlns:xlink="http://www.w3.org/1999/xlink"))
    end
  end

  describe "vendored DTD" do
    it "matches the manifest checksum" do
      entry = YAML.safe_load_file(described_class::MANIFEST_PATH, permitted_classes: [Date])["files"].first

      expect(Digest::SHA256.file(dtd_path).hexdigest).to eq(entry["sha256"])
      expect(entry["source_url"]).to start_with("https://www.w3.org/")
    end
  end
end
