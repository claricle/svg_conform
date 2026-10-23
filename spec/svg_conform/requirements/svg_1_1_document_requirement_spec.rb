# frozen_string_literal: true

require "spec_helper"

# Path is fixed by the card; the cop expects svg11_ instead of svg_1_1_.
RSpec.describe SvgConform::Requirements::Svg11DocumentRequirement do # rubocop:disable RSpec/SpecFilePathFormat
  let(:svg_ns) { 'xmlns="http://www.w3.org/2000/svg"' }
  let(:profile_path) { "config/profiles/svg_1_1_full_static.yml" }

  def requirement_for(rule)
    SvgConform::Profile.load_from_file(profile_path).requirements.find do |req|
      req.respond_to?(:rule) && req.rule == rule
    end
  end

  def run(rule, xml, mode: :sax, serialized: false)
    requirement = requirement_for(rule)
    profile = SvgConform::Profile.new(name: "t", requirements: [requirement])
    if mode == :dom
      profile.validate(SvgConform::Document.from_content(xml)).errors
    else
      SvgConform::SaxDocument.from_content(xml, source_serialized: serialized)
        .validate_with_profile(profile).errors
    end
  end

  def doc(attrs: 'version="1.1"', body: '<rect width="1" height="1"/>', prolog: "")
    %(<?xml version="1.0"?>\n#{prolog}<svg #{svg_ns} #{attrs}>#{body}</svg>)
  end

  it "defines one entry per matrix row with its own id and citation" do
    entries = SvgConform::Profile.load_from_file(profile_path).requirements
      .grep(described_class)
    expect(entries.map(&:rule)).to eq(described_class::RULES)
    expect(entries.map(&:id)).to eq(
      %w[svg11.document.xml svg11.document.root svg11.document.version
         svg11.document.grammar svg11.document.css2
         svg11.document.xml_stylesheet],
    )
    expect(entries.map(&:citation_uri)).to all(start_with("https://www.w3.org/TR/"))
  end

  it "is registered in Requirements.all" do
    expect(SvgConform::Requirements.all).to include(described_class)
  end

  it "rejects an unknown rule" do
    requirement = described_class.new(id: "x", rule: "nope")
    context = SvgConform::ValidationContext.new(nil, nil, source: "<svg/>")
    expect { requirement.validate_source("<svg/>", context) }
      .to raise_error(ArgumentError, /unknown rule/)
  end

  %i[sax dom].each do |mode|
    context "when validating in #{mode} mode" do
      it "accepts a valid document in every rule" do
        described_class::RULES.each do |rule|
          expect(run(rule, doc, mode: mode)).to be_empty, "rule #{rule}"
        end
      end

      it "flags a wrong root namespace" do
        errors = run("root", doc.sub(svg_ns, 'xmlns="http://example.com/x"'), mode: mode)
        expect(errors.map(&:requirement_id)).to eq(["svg11.document.root"])
      end

      it "flags a wrong or missing version" do
        expect(run("version", doc(attrs: 'version="1.0"'), mode: mode).size).to eq(1)
        expect(run("version", doc(attrs: ""), mode: mode).size).to eq(1)
      end

      it "flags DTD content-model and attribute violations" do
        model = run("grammar", doc(body: "<rect><g/></rect>"), mode: mode)
        attribute = run("grammar", doc(body: '<rect width="1" height="1" bogus="1"/>'), mode: mode)
        expect(model.map(&:requirement_id)).to all(eq("svg11.document.grammar"))
        expect(model).not_to be_empty
        expect(attribute).not_to be_empty
      end

      it "does not follow an external entity" do
        xml = "<?xml version=\"1.0\"?>\n<!DOCTYPE svg [<!ENTITY x SYSTEM \"file:///etc/passwd\">]>\n<svg #{svg_ns} version=\"1.1\"><title>&x;</title></svg>"
        errors = run("grammar", xml, mode: mode)
        expect(errors.map(&:message).join).to include("external")
        expect(errors.map(&:message).join).not_to include("root:")
      end

      it "flags CSS grammar errors in style attributes and style elements" do
        attr = run("css2", doc(body: '<rect width="1" height="1" style="fill: {red"/>'), mode: mode)
        sheet = run("css2", doc(body: "<style>rect { fill: red </style>"), mode: mode)
        expect(attr.size).to be >= 1
        expect(sheet.size).to be >= 1
      end

      it "accepts valid CSS and skips non-CSS style types" do
        css = "<style>rect { fill: red }</style><style type=\"text/x-other\">{{</style>"
        expect(run("css2", doc(body: css), mode: mode)).to be_empty
      end

      it "validates xml-stylesheet pseudo-attributes" do
        good = doc(prolog: %(<?xml-stylesheet href="a.css" type="text/css"?>\n))
        no_href = doc(prolog: %(<?xml-stylesheet type="text/css"?>\n))
        bad_type = doc(prolog: %(<?xml-stylesheet href="a.xsl" type="text/xsl"?>\n))
        garbled = doc(prolog: %(<?xml-stylesheet href=a.css?>\n))
        expect(run("xml_stylesheet", good, mode: mode)).to be_empty
        [no_href, bad_type, garbled].each do |xml|
          expect(run("xml_stylesheet", xml, mode: mode).map(&:requirement_id))
            .to eq(["svg11.document.xml_stylesheet"])
        end
      end
    end
  end

  it "reports malformed XML through SAX" do
    errors = run("xml", "<svg #{svg_ns}><rect></svg>")
    expect(errors.map(&:requirement_id)).to include("svg11.document.xml")
  end

  it "cannot prove declaration claims for a re-serialized source" do
    errors = run("xml", doc, serialized: true)
    expect(errors.map(&:requirement_id)).to eq(["svg11.document.xml"])
    expect(errors.first.message).to include("cannot be proved")
    expect(run("xml", doc, serialized: false)).to be_empty
  end

  it "reports the same through a DOM node and a serialized SAX source" do
    node = SvgConform::Document.from_content(doc).moxml_document
    dom = SvgConform::Document.from_node(node)
    profile = SvgConform::Profile.new(name: "t", requirements: [requirement_for("xml")])
    expect(profile.validate(dom).errors.map(&:requirement_id))
      .to eq(["svg11.document.xml"])
  end
end
