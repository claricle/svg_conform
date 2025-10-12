# frozen_string_literal: true

require "ox"
require "moxml/adapter/ox"

RSpec.describe Moxml::Adapter::Ox, skip: "Ox will be added later" do
  before(:all) do
    Moxml.configure do |config|
      config.adapter = :ox
      config.strict_parsing = true
      config.default_encoding = "UTF-8"
    end
  end

  it_behaves_like "xml adapter"

  describe "text handling" do
    let(:doc) { described_class.create_document }
    let(:element) { described_class.create_native_element("test") }

    it "creates text nodes as strings" do
      text = described_class.create_native_text("content")
      expect(text).to be_a(String)
      expect(text).to eq("content")
    end

    it "adds text nodes to elements" do
      text = described_class.create_native_text("content")
      described_class.add_child(element, text)
      expect(element.nodes.first).to eq("content")
    end
  end

  describe "xpath support" do
    let(:doc) { described_class.parse("<root><child id='1'>text</child></root>") }

    it "supports basic element matching" do
      nodes = described_class.xpath(doc, "//child")
      expect(nodes.size).to eq(1)
      expect(nodes.first.name).to eq("child")
    end

    it "supports attribute matching" do
      nodes = described_class.xpath(doc, "//child[@id='1']")
      expect(nodes.size).to eq(1)
      expect(nodes.first.attributes["id"]).to eq("1")
    end
  end
end
