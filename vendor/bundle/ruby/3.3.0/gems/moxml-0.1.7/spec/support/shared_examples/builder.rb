# frozen_string_literal: true

RSpec.shared_examples "Moxml::Builder" do
  let(:context) { Moxml.new }
  let(:builder) { Moxml::Builder.new(context) }

  describe "#document" do
    let(:doc) do
      builder.build do
        declaration version: "1.0", encoding: "UTF-8"
        element "root" do
          element "child", id: "1" do
            text "content"
          end
        end
      end
    end

    it "creates a well-formed document" do
      xml = doc.to_xml
      expect(xml).to include('<?xml version="1.0" encoding="UTF-8"?>')
      expect(xml).to include("<root>")
      expect(xml).to include('<child id="1">content</child>')
      expect(xml).to include("</root>")
    end

    it "creates the same document through direct manipulation" do
      doc2 = context.create_document
      doc2.add_child(doc2.create_declaration("1.0", "UTF-8"))
      root = doc2.create_element("root")
      child = doc2.create_element("child")
      child["id"] = "1"
      text = doc2.create_text("content")

      child.add_child(text)
      root.add_child(child)
      doc2.add_child(root)

      expect(doc.to_xml).to eq(doc2.to_xml)
    end
  end
end
