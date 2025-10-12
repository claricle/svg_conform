# frozen_string_literal: true

RSpec.shared_examples "Moxml Edge Cases" do
  let(:context) { Moxml.new }

  describe "special characters handling" do
    it "handles all kinds of whitespace", skip: "carriege returns are troublesome" do
      # Nokogiri can't handle carriege returns properly
      # https://github.com/sparklemotion/nokogiri/issues/1356
      xml = "<root>\u0020\u0009 \u000D\u000A \u000D</root>"
      doc = context.parse(xml)
      expect(doc.root.text).to eq(" \t \r\n \r")
    end

    it "handles unicode characters" do
      text = "Hello 世界 🌍"
      doc = context.create_document
      element = doc.create_element("test")
      element.text = text
      expect(element.text).to eq(text)
    end

    it "handles zero-width characters" do
      text = "test\u200B\u200Ctest"
      doc = context.create_document
      element = doc.create_element("test")
      element.text = text
      expect(element.text).to eq(text)
    end
  end

  describe "malformed content handling" do
    it "handles CDATA with nested markers" do
      pending "Ox doesn't escape the end token" if context.config.adapter_name == :ox
      cdata_text = "]]>]]>]]>"
      doc = context.create_document
      cdata = doc.create_cdata(cdata_text)
      expect(cdata.to_xml).to include(
        "]]]]><![CDATA[>]]]]><![CDATA[>]]]]><![CDATA[>"
      )
    end

    it "handles invalid processing instruction content" do
      content = "?> invalid"
      doc = context.create_document
      pi = doc.create_processing_instruction("test", content)
      expect(pi.to_xml).not_to include("?>?>")
    end

    it "rejects comments with double hyphens" do
      doc = context.create_document
      expect do
        doc.create_comment("-- test -- comment --")
      end.to raise_error(Moxml::ValidationError, "XML comment cannot start or end with a hyphen")
    end

    it "rejects comments starting with hyphen" do
      doc = context.create_document
      expect do
        doc.create_comment("-starting with hyphen")
      end.to raise_error(Moxml::ValidationError, "XML comment cannot start or end with a hyphen")
    end

    it "rejects comments ending with hyphen" do
      doc = context.create_document
      expect do
        doc.create_comment("ending with hyphen-")
      end.to raise_error(Moxml::ValidationError, "XML comment cannot start or end with a hyphen")
    end

    it "accepts valid comments" do
      doc = context.create_document
      comment = doc.create_comment("valid - comment")
      expect(comment.content).to eq("valid - comment")
    end
  end

  describe "namespace edge cases" do
    it "handles default namespace changes" do
      pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox
      xml = <<~XML
        <root xmlns="http://default1.org">
          <child xmlns="http://default2.org">
            <grandchild xmlns=""/>
          </child>
        </root>
      XML

      doc = context.parse(xml)
      grandchild = doc.at_xpath("//xmlns:grandchild", "xmlns" => "")
      expect(grandchild.namespaces.first.uri).to eq("")
    end

    it "handles recursive namespace definitions" do
      pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

      xml = <<~XML
        <root xmlns:a="http://a.org">
          <a:child xmlns:a="http://b.org">
            <a:grandchild/>
          </a:child>
        </root>
      XML

      doc = context.parse(xml)
      grandchild = doc.at_xpath("//a:grandchild", "a" => "http://b.org")
      expect(grandchild.namespace.uri).to eq("http://b.org")
    end
  end

  describe "attribute edge cases" do
    it "handles attributes with same local name but different namespaces" do
      pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

      xml = <<~XML
        <root xmlns:a="http://a.org" xmlns:b="http://b.org">
          <element a:id="1" b:id="2"/>
        </root>
      XML

      doc = context.parse(xml)
      element = doc.at_xpath("//element")
      expect(element["a:id"]).to eq("1")
      expect(element["b:id"]).to eq("2")
    end

    it "handles special attribute values" do
      doc = context.create_document
      element = doc.create_element("test")

      special_values = {
        "empty" => "",
        "space" => " ",
        "tabs_newlines" => "\t\n",
        "unicode" => "⚡",
        "entities" => "<&>'\""
      }

      special_values.each do |name, value|
        element[name] = value
        expect(element[name]).to eq(value)
      end
    end
  end

  describe "document structure edge cases" do
    it "handles deeply nested elements" do
      doc = context.create_document
      current = doc.create_element("root")
      doc.add_child(current)

      10.times do |i|
        nested = doc.create_element("nested#{i}")
        current.add_child(nested)
        current = nested
      end

      expect(doc.to_xml).to include("<nested9>")
    end

    it "handles large number of siblings" do
      doc = context.create_document
      root = doc.create_element("root")
      doc.add_child(root)

      1000.times do |i|
        child = doc.create_element("child")
        child.text = i.to_s
        root.add_child(child)
      end

      expect(root.children.size).to eq(1000)
    end

    it "handles mixed content with all node types" do
      doc = context.create_document
      root = doc.create_element("root")
      doc.add_child(root)

      root.add_child("text1")
      root.add_child(doc.create_comment("comment"))
      root.add_child("text2")
      root.add_child(doc.create_cdata("<tag>"))
      root.add_child(doc.create_element("child"))
      root.add_child("text3")
      root.add_child(doc.create_processing_instruction("pi", "data"))

      expect(root.children.size).to eq(7)
    end
  end
end
