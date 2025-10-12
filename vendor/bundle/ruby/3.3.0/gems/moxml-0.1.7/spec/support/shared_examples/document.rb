# frozen_string_literal: true

RSpec.shared_examples "Moxml::Document" do
  let(:context) { Moxml.new }
  let(:xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE html>
      <root xmlns="http://example.org" xmlns:x="http://example.org/x">
        <child id="1">Text</child>
        <child id="2"/>
        <x:special>
          <![CDATA[Some <special> text]]>
          <!-- A comment -->
          <?pi target?>
        </x:special>
      </root>
    XML
  end

  describe "#parse" do
    let(:doc) { context.parse(xml) }

    it "parses XML string" do
      expect(doc).to be_a(Moxml::Document)
      expect(doc.root.name).to eq("root")
    end

    it "preserves XML declaration" do
      expect(doc.to_xml).to include('<?xml version="1.0" encoding="UTF-8"?>')
    end

    it "handles namespaces" do
      expect(doc.root.namespaces.size).to eq(2)
    end

    it "preserves DOCTYPE" do
      expect(doc.to_xml).to include("<!DOCTYPE html>")
    end

    it "raises error for invalid XML when strict" do
      context.config.strict_parsing = true
      expect { context.parse("<invalid>") }.to raise_error(Moxml::ParseError)
    end
  end

  describe "node creation" do
    let(:doc) { context.create_document }

    it "creates element" do
      element = doc.create_element("test")
      expect(element).to be_a(Moxml::Element)
      expect(element.name).to eq("test")
    end

    it "creates text" do
      text = doc.create_text("content")
      expect(text).to be_a(Moxml::Text)
      expect(text.content).to eq("content")
    end

    it "creates CDATA" do
      cdata = doc.create_cdata("<content>")
      expect(cdata).to be_a(Moxml::Cdata)
      expect(cdata.content).to eq("<content>")
    end

    it "creates comment" do
      comment = doc.create_comment("comment")
      expect(comment).to be_a(Moxml::Comment)
      expect(comment.content).to eq("comment")
    end

    it "creates processing instruction" do
      pi = doc.create_processing_instruction("target", "content")
      expect(pi).to be_a(Moxml::ProcessingInstruction)
      expect(pi.target).to eq("target")
      expect(pi.content).to eq("content")
    end

    it "creates declaration" do
      decl = doc.create_declaration("1.0", "UTF-8", "yes")
      expect(decl).to be_a(Moxml::Declaration)
      expect(decl.version).to eq("1.0")
      expect(decl.encoding).to eq("UTF-8")
      expect(decl.standalone).to eq("yes")
    end
  end

  describe "document structure" do
    let(:doc) { context.create_document }

    it "builds complete document" do
      doc.add_child(doc.create_declaration("1.0", "UTF-8"))
      root = doc.create_element("root")
      doc.add_child(root)

      child = doc.create_element("child")
      child.add_child(doc.create_text("text"))
      root.add_child(child)

      expect(doc.to_xml).to include(
        '<?xml version="1.0" encoding="UTF-8"?>',
        "<root>",
        "<child>text</child>",
        "</root>"
      )
    end

    it "prevents multiple roots" do
      xml =
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <root/><another_root/>
        XML

      expect { context.parse(xml) }.to raise_error(Moxml::Error)
    end
  end
end
