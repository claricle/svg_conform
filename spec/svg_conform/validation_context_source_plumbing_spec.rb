# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe SvgConform::ValidationContext, "#source" do
  let(:source) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!-- exact bytes -->
      <?xml-stylesheet href="a.css" type="text/css"?>
      <svg xmlns="http://www.w3.org/2000/svg" version="1.1"><rect width="1" height="1"/></svg>
    XML
  end

  let(:recorder_class) do
    Class.new(SvgConform::Requirements::BaseRequirement) do
      attr_accessor :calls

      def validate_source(source, context)
        (@calls ||= []) << {
          source: source, path: context.source_path,
          serialized: context.source_serialized?, order: :source
        }
      end

      def validate_sax_element(_element, _context)
        (@calls ||= []) << { order: :element }
      end

      def check(_node, _context)
        (@calls ||= []) << { order: :element }
      end
    end
  end

  let(:requirement) { recorder_class.new(id: "rec") }
  let(:profile) { SvgConform::Profile.new(name: "rec", requirements: [requirement]) }

  def sources_seen
    requirement.calls.select { |c| c[:order] == :source }
  end

  it "keeps the BaseRequirement hook a no-op" do
    base = SvgConform::Requirements::BaseRequirement.new(id: "b")
    expect(base.validate_source("x", nil)).to be_nil
  end

  it "stores source and path on ValidationContext" do
    ctx = described_class.new(nil, nil, source: "s",
                                        source_path: "p.svg")
    expect([ctx.source, ctx.source_path, ctx.source_serialized?])
      .to eq(["s", "p.svg", false])
    expect(described_class.new(nil, nil).source).to be_nil
  end

  it "retains exact content in Document for string and file inputs" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "a.svg")
      File.write(path, source)
      expect(SvgConform::Document.from_content(source).source).to eq(source)
      from_file = SvgConform::Document.from_file(path)
      expect(from_file.source).to eq(source)
      expect(from_file.source_serialized?).to be(false)
    end
  end

  it "marks Document.from_node source as serialized" do
    node = SvgConform::Document.from_content(source).moxml_document
    doc = SvgConform::Document.from_node(node)
    expect(doc.source_serialized?).to be(true)
    expect(doc.source).to include("<svg")
  end

  it "passes SaxDocument content into the handler" do
    SvgConform::SaxDocument.from_content(source).validate_with_profile(profile)
    expect(sources_seen.size).to eq(1)
    expect(sources_seen.first).to include(source: source, path: nil,
                                          serialized: false)
  end

  it "calls validate_source exactly once, before elements, in DOM and SAX" do
    profile.validate(SvgConform::Document.from_content(source))
    dom_orders = requirement.calls.map { |c| c[:order] }
    expect(dom_orders.first).to eq(:source)
    expect(dom_orders.count(:source)).to eq(1)

    requirement.calls = []
    SvgConform::SaxDocument.from_content(source).validate_with_profile(profile)
    sax_orders = requirement.calls.map { |c| c[:order] }
    expect(sax_orders.first).to eq(:source)
    expect(sax_orders.count(:source)).to eq(1)
  end

  it "gives file entry points identical source and path in both modes" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "a.svg")
      File.write(path, source)

      profile.validate_file(path)
      sax = sources_seen.first
      requirement.calls = []
      profile.validate(SvgConform::Document.from_file(path))
      dom = sources_seen.first

      expect(sax).to include(source: source, path: path, serialized: false)
      expect(dom).to eq(sax)
    end
  end

  it "flags serialized source for DOM built from a node" do
    node = SvgConform::Document.from_content(source).moxml_document
    profile.validate(SvgConform::Document.from_node(node))
    expect(sources_seen.first[:serialized]).to be(true)
  end

  it "still runs source validation when SAX parsing fails" do
    SvgConform::SaxDocument.from_content("<svg><unclosed>")
      .validate_with_profile(profile)
    expect(sources_seen.size).to eq(1)
  end
end
