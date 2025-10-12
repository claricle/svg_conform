# frozen_string_literal: true

RSpec.shared_examples "Basic Usage Examples" do
  let(:context) { Moxml.new }

  describe "Document creation" do
    it "creates basic document" do
      doc = context.create_document
      root = doc.create_element("book")
      doc.add_child(root)

      expect(doc.to_xml).to include("<book></book>")
    end

    it "creates document with declaration" do
      doc = context.create_document
      doc.add_child(doc.create_declaration("1.0", "UTF-8"))
      root = doc.create_element("book")
      doc.add_child(root)

      expect(doc.to_xml).to include(
        '<?xml version="1.0" encoding="UTF-8"?>',
        "<book></book>"
      )
    end

    it "creates document with processing instructions" do
      doc = context.create_document
      pi = doc.create_processing_instruction("xml-stylesheet",
                                             'type="text/xsl" href="style.xsl"')
      doc.add_child(pi)
      doc.add_child(doc.create_element("root"))

      expect(doc.to_xml).to include(
        '<?xml-stylesheet type="text/xsl" href="style.xsl"?>',
        "<root></root>"
      )
    end
  end

  describe "Node creation" do
    let(:doc) { context.create_document }

    it "creates different node types" do
      element = doc.create_element("test")
      text = doc.create_text("content")
      cdata = doc.create_cdata("<xml>data</xml>")
      comment = doc.create_comment("note")
      pi = doc.create_processing_instruction("target", "data")

      root = doc.create_element("root")
      doc.add_child(root)
      root.add_child(element)
      root.add_child(text)
      root.add_child(cdata)
      root.add_child(comment)
      root.add_child(pi)

      xml = doc.to_xml
      expect(xml).to include("<test></test>")
      expect(xml).to include("content")
      expect(xml).to include("<![CDATA[<xml>data</xml>]]>")
      expect(xml).to include("<!--note-->")
      expect(xml).to include("<?target data?>")
    end
  end
end
