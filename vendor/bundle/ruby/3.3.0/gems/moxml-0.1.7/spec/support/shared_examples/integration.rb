# frozen_string_literal: true

RSpec.shared_examples "Moxml Integration" do
  let(:context) { Moxml.new }

  describe "complete document workflow" do
    let(:doc) { context.create_document }
    before do
      # Create document with declaration
      doc.add_child(doc.create_declaration("1.0", "UTF-8"))

      # Add root with namespaces
      root = doc.create_element("root")
      root.add_namespace(nil, "http://example.org")
      root.add_namespace("xs", "http://www.w3.org/2001/XMLSchema")
      doc.add_child(root)

      # Add processing instruction
      style_pi = doc.create_processing_instruction("xml-stylesheet", 'type="text/xsl" href="style.xsl"')
      root.add_previous_sibling(style_pi)

      # Add mixed content
      root.add_child(doc.create_comment(" Mixed content example "))

      text_node = doc.create_element("text")
      text_node.add_child("Some text ")
      text_node.add_child(doc.create_cdata("<with><markup/>"))
      text_node.add_child(" and more text")
      root.add_child(text_node)

      # Add element with attributes
      item = doc.create_element("item")
      item["id"] = "123"
      item["xs:type"] = "custom"
      root.add_child(item)
    end

    it "has correct xml elements" do
      # Verify structure
      expected_xml_tags = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<?xml-stylesheet type="text/xsl" href="style.xsl"?>',
        '<root xmlns="http://example.org" xmlns:xs="http://www.w3.org/2001/XMLSchema">',
        "<!-- Mixed content example -->",
        "<text>Some text <![CDATA[<with><markup/>]]> and more text</text>",
        '<item id="123" xs:type="custom"></item>',
        "</root>"
      ]

      expected_xml_tags.each do |expected_xml|
        # include(*expected_xml_tags) is shorter but worse for debugging
        expect(doc.to_xml).to include(expected_xml)
      end
    end

    it "handles xpath queries" do
      pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox
      # Test XPath queries
      #
      # XPath with a default namespace is a problem
      # Nokogiri:
      # https://timnew.me/blog/2012/10/25/pitfall-in-nokogiri-xpath-and-namespace/
      # Oga:
      # https://www.rubydoc.info/gems/oga/0.3.3#namespace-support
      expect(doc.xpath('//xmlns:item[@id="123"]')).not_to be_empty
      expect(doc.at_xpath("//xmlns:text").text).to include("Some text")
    end
  end

  describe "namespace handling" do
    it "handles complex namespace scenarios" do
      pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox
      xml = <<~XML
        <root xmlns="http://default.org" xmlns:a="http://a.org" xmlns:b="http://b.org">
          <child>
            <a:element b:attr="value">
              <deeper xmlns="http://other.org"/>
            </a:element>
          </child>
        </root>
      XML

      doc = context.parse(xml)

      # Test root namespace
      root = doc.root
      expect(root.namespace.prefix).to be_nil
      expect(root.namespace.uri).to eq("http://default.org")

      # Test namespace inheritance
      child = doc.at_xpath("//xmlns:child")
      expect(child.namespace.uri).to eq("http://default.org")

      # Test namespace prefix resolution
      a_element = doc.at_xpath("//a:element", "a" => "http://a.org")
      expect(a_element).not_to be_nil
      expect(a_element.namespace.prefix).to eq("a")

      # Test attribute namespace
      attr = a_element["b:attr"]
      expect(attr).to eq("value")

      # Test namespace override
      deeper = a_element.children.first
      expect(deeper.namespace.uri).to eq("http://other.org")
    end
  end

  describe "document modification" do
    let(:doc) { context.parse("<root><a>1</a><b>2</b></root>") }

    it "handles complex modifications" do
      pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

      # Move nodes
      b_node = doc.at_xpath("//b")
      a_node = doc.at_xpath("//a")
      a_node.add_previous_sibling(b_node)

      # Add nodes
      c_node = doc.create_element("c")
      c_node.add_child("3")
      b_node.add_next_sibling(c_node)

      # Modify attributes
      doc.root["id"] = "main"

      # Add mixed content
      b_node.add_child(doc.create_comment(" comment "))
      b_node.add_child(doc.create_cdata("<tag>"))

      expect(doc.root.children.map(&:name)).to eq(%w[b c a])
      expect(doc.to_xml).to include(
        '<root id="main">',
        "<b>2<!-- comment --><![CDATA[<tag>]]></b>"
      )
    end
  end
end
