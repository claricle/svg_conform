# frozen_string_literal: true

RSpec.shared_examples "Moxml::Context" do
  let(:context) { Moxml::Context.new }

  describe "#parse" do
    it "returns a Moxml::Document" do
      doc = context.parse("<root/>")
      expect(doc).to be_a(Moxml::Document)
    end

    it "builds complete document model" do
      doc = context.parse("<root><child>text</child></root>")
      expect(doc.root).to be_a(Moxml::Element)
      expect(doc.root.children.first).to be_a(Moxml::Element)
      expect(doc.root.children.first.children.first).to be_a(Moxml::Text)
    end

    it "maintains document structure", skip: "Nokogiri doesn't consider the declaration as a child node" do
      xml = <<~XML
        <?xml version="1.0"?>
        <!-- comment -->
        <root>
          <![CDATA[data]]>
          <?pi target?>
        </root>
      XML
      doc = context.parse(xml)

      expect(doc.children[1]).to be_a(Moxml::Comment)
      expect(doc.at_xpath("//root").children[0]).to be_a(Moxml::Cdata)
      expect(doc.at_xpath("//root").children[1]).to be_a(Moxml::ProcessingInstruction)
    end
  end
end
