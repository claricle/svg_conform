# frozen_string_literal: true

RSpec.shared_examples "Moxml::Cdata" do
  let(:context) { Moxml.new }
  let(:doc) { context.create_document }
  let(:cdata) { doc.create_cdata("<content>") }

  it "identifies as CDATA node" do
    expect(cdata).to be_cdata
  end

  describe "content manipulation" do
    it "gets content" do
      expect(cdata.content).to eq("<content>")
    end

    it "sets content" do
      cdata.content = "new <content>"
      expect(cdata.content).to eq("new <content>")
    end

    it "handles nil content" do
      cdata.content = nil
      expect(cdata.content).to eq("")
    end

    it "preserves whitespace" do
      cdata.content = "  spaced  content\n\t"
      expect(cdata.content).to eq("  spaced  content\n\t")
    end
  end

  describe "serialization" do
    it "wraps content in CDATA section" do
      expect(cdata.to_xml).to eq("<![CDATA[<content>]]>")
    end

    it "escapes CDATA end marker" do
      # pending for Ox: https://github.com/ohler55/ox/issues/377
      pending "Ox doesn't escape the end token" if context.config.adapter_name == :ox
      cdata.content = "content]]>more"
      expect(cdata.to_xml).to eq("<![CDATA[content]]]]><![CDATA[>more]]>")
    end

    it "handles special characters" do
      cdata.content = "< > & \" '"
      expect(cdata.to_xml).to include("< > & \" '")
    end
  end

  describe "node operations" do
    let(:element) { doc.create_element("test") }

    it "adds to element" do
      element.add_child(cdata)
      expect(element.to_xml).to include("<![CDATA[<content>]]>")
    end

    it "removes from element" do
      element.add_child(cdata)
      cdata.remove
      expect(element.children).to be_empty
    end

    it "replaces with another node" do
      element.add_child(cdata)
      text = doc.create_text("replacement")
      cdata.replace(text)
      expect(element.text).to eq("replacement")
    end
  end
end
