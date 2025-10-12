# frozen_string_literal: true

# This test works directly with native nodes which looks quite strange
# A better way is to run it through Moxml wrappers
RSpec.shared_examples "xml adapter" do
  let(:xml) do
    <<~XML
      <?xml version="1.0"?>
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

  describe ".parse" do
    it "parses XML string" do
      doc = described_class.parse(xml).native
      expect(described_class.node_type(doc)).to eq(:document)
      expect(described_class.node_name(described_class.root(doc))).to eq("root")
    end

    it "handles malformed XML according to strict setting" do
      malformed = "<root><unclosed>"

      expect do
        described_class.parse(malformed, strict: true)
      end.to raise_error(Moxml::ParseError)

      expect do
        described_class.parse(malformed, strict: false)
      end.not_to raise_error
    end
  end

  describe "node creation" do
    let(:doc) { described_class.create_document }

    it "creates element" do
      element = described_class.create_element("test")
      expect(described_class.node_type(element)).to eq(:element)
      expect(described_class.node_name(element)).to eq("test")
    end

    it "creates text" do
      text = described_class.create_text("content")
      expect(described_class.node_type(text)).to eq(:text)
    end

    it "creates CDATA" do
      cdata = described_class.create_cdata("<content>")
      expect(described_class.node_type(cdata)).to eq(:cdata)
    end

    it "creates comment" do
      comment = described_class.create_comment("comment")
      expect(described_class.node_type(comment)).to eq(:comment)
    end

    it "creates processing instruction" do
      pi = described_class.create_processing_instruction("target", "content")
      expect(described_class.node_type(pi)).to eq(:processing_instruction)
    end
  end

  describe "node manipulation" do
    let(:doc) { described_class.parse(xml).native }
    let(:root) { described_class.root(doc) }

    it "gets parent" do
      child = described_class.children(root).first
      expect(described_class.parent(child)).to eq(root)
    end

    it "gets children" do
      children = described_class.children(root)
      expect(children.length).to eq(3)
    end

    it "gets siblings" do
      children = described_class.children(root)
      first = children[0]
      second = children[1]

      expect(described_class.next_sibling(first)).to eq(second)
      expect(described_class.previous_sibling(second)).to eq(first)
    end

    it "adds child" do
      element = described_class.create_element("new")
      described_class.add_child(root, element)
      expect(described_class.children(root).last).to eq(element)
    end

    it "adds text child" do
      described_class.add_child(root, "text")
      # a workaround for Rexml until we convert tests to work with Moxml wrappers
      last_child = described_class.children(root).last
      last_text = last_child.respond_to?(:text) ? last_child.text : last_child.to_s
      expect(last_text).to eq("text")
    end
  end

  describe "attributes" do
    let(:doc) { described_class.parse(xml).native }
    let(:element) { described_class.children(described_class.root(doc)).first }

    it "gets attributes" do
      attrs = described_class.attributes(element)
      expect(attrs.count).to eq(1)
      expect(attrs.first.value).to eq("1")
    end

    it "sets attribute" do
      described_class.set_attribute(element, "new", "value")
      expect(described_class.get_attribute(element, "new").value).to eq("value")
    end

    it "removes attribute" do
      described_class.remove_attribute(element, "id")
      expect(described_class.get_attribute(element, "id")&.value).to be_nil
    end

    it "handles special characters in attributes" do
      described_class.set_attribute(element, "special", '< > & " \'')
      # a workaround for Rexml until we convert tests to work with Moxml wrappers
      attr = described_class.get_attribute(element, "special")
      value = attr.respond_to?(:to_xml) ? attr&.to_xml : attr.to_s
      expect(value).to match(/&lt; &gt; &amp; (&quot;|") ('|&apos;)/)
    end
  end

  describe "namespaces" do
    let(:doc) { described_class.parse(xml).native }
    let(:root) { described_class.root(doc) }
    let(:special) { described_class.children(root).last }

    it "creates namespace" do
      ns = described_class.create_namespace(root, "test", "http://test.org")
      expect(ns).not_to be_nil
    end

    it "handles namespaced elements" do
      expect(described_class.node_name(special)).to eq("special")
    end
  end

  describe "serialization" do
    let(:doc) { described_class.parse(xml).native }

    it "serializes to XML" do
      result = described_class.serialize(doc)

      expect(result).to include("<?xml")
      expect(result).to include("<root")
      expect(result).to include('xmlns="http://example.org"').once
      expect(result).to include('xmlns:x="http://example.org/x"').once
      expect(result).to include("</root>")
    end

    it "respects indentation settings" do
      pending("Oga does not support indentation settings") if described_class.name.include?("Oga")
      pending("Postponed for Rexml till better times") if described_class.name.include?("Rexml")

      unindented = described_class.serialize(doc, indent: 0)
      indented = described_class.serialize(doc, indent: 2)

      expect(unindented).not_to include("\n  ")
      expect(indented).to include("\n  ")
    end

    it "preserves XML declaration" do
      result = described_class.serialize(doc)
      expect(result).to match(/^<\?xml/)
    end

    it "handles encoding specification" do
      result = described_class.serialize(doc, encoding: "UTF-8")
      expect(result).to include('encoding="UTF-8"')
    end
  end

  describe "xpath" do
    let(:doc) { described_class.parse(xml).native }

    it "finds nodes by xpath" do
      nodes = described_class.xpath(doc, "//xmlns:child")
      expect(nodes.length).to eq(2)
    end

    it "finds first node by xpath" do
      node = described_class.at_xpath(doc, "//xmlns:child")
      expect(described_class.get_attribute_value(node, "id")).to eq("1")
    end
  end

  describe "namespace handling" do
    context "case 1" do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <svg xmlns="http://www.w3.org/2000/svg"
               xmlns:xlink="http://www.w3.org/1999/xlink"
               width="100" height="100">
            <defs>
              <circle id="myCircle" cx="50" cy="50" r="40"/>
            </defs>
            <use xlink:href="#myCircle" fill="red"/>
            <text x="50" y="50" text-anchor="middle">SVG</text>
          </svg>
        XML
      end

      it "preserves and correctly handles multiple namespaces" do
        pending("Rexml does not respect ZPath namespaces") if described_class.name.include?("Rexml")
        # Parse original XML
        doc = described_class.parse(xml).native

        # Test namespace preservation in serialization
        result = described_class.serialize(doc)
        expect(result).to include('xmlns="http://www.w3.org/2000/svg"')
        expect(result).to include('xmlns:xlink="http://www.w3.org/1999/xlink"')

        # Test xpath with namespaces
        namespaces = {
          "svg" => "http://www.w3.org/2000/svg",
          "xlink" => "http://www.w3.org/1999/xlink"
        }

        # Find use element and verify xlink:href attribute
        use_elem = described_class.at_xpath(doc, "//svg:use", namespaces)
        expect(use_elem).not_to be_nil
        expect(described_class.get_attribute_value(use_elem, "xlink:href")).to eq("#myCircle")

        # Verify circle element exists in defs
        circle = described_class.at_xpath(doc, "//svg:defs/svg:circle", namespaces)
        expect(circle).not_to be_nil
        expect(described_class.get_attribute_value(circle, "id")).to eq("myCircle")

        # Test default SVG namespace
        text = described_class.at_xpath(doc, "//svg:text", namespaces)
        expect(described_class.text_content(text)).to eq("SVG")
      end
    end

    context "case 2" do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <rss version="2.0"#{" "}
            xmlns:atom="http://www.w3.org/2005/Atom"
            xmlns:dc="http://purl.org/dc/elements/1.1/"
            xmlns:content="http://purl.org/rss/1.0/modules/content/">
            <channel>
              <title>Example RSS Feed</title>
              <atom:link href="http://example.com/feed" rel="self"/>
              <item>
                <title>Example Post</title>
                <dc:creator>John Doe</dc:creator>
                <content:encoded><![CDATA[<p>Post content</p>]]></content:encoded>
              </item>
            </channel>
          </rss>
        XML
      end

      it "preserves and correctly handles multiple namespaces" do
        # Parse original XML
        doc = described_class.parse(xml).native

        # Test namespace preservation in serialization
        result = described_class.serialize(doc)
        expect(result).to include('xmlns:atom="http://www.w3.org/2005/Atom"')
        expect(result).to include('xmlns:dc="http://purl.org/dc/elements/1.1/"')
        expect(result).to include('xmlns:content="http://purl.org/rss/1.0/modules/content/"')

        # Test xpath with namespaces
        namespaces = {
          "atom" => "http://www.w3.org/2005/Atom",
          "dc" => "http://purl.org/dc/elements/1.1/",
          "content" => "http://purl.org/rss/1.0/modules/content/"
        }

        # Find creator using namespaced xpath
        creator = described_class.at_xpath(doc, "//dc:creator", namespaces)
        expect(described_class.text_content(creator)).to eq("John Doe")

        # Verify atom:link exists
        link = described_class.at_xpath(doc, "//atom:link", namespaces)
        expect(link).not_to be_nil
        expect(described_class.get_attribute_value(link, "href")).to eq("http://example.com/feed")

        # Verify CDATA in content:encoded
        content = described_class.at_xpath(doc, "//content:encoded", namespaces)
        expect(described_class.text_content(content)).to eq("<p>Post content</p>")
      end
    end

    context "case 3" do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soap:Envelope#{" "}
            xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xmlns:ns="urn:example:namespace">
            <soap:Header>
              <ns:SessionId>12345</ns:SessionId>
            </soap:Header>
            <soap:Body>
              <ns:GetUserRequest>
                <ns:UserId xsi:type="xsi:string">user123</ns:UserId>
              </ns:GetUserRequest>
            </soap:Body>
          </soap:Envelope>
        XML
      end

      it "preserves and correctly handles multiple namespaces" do
        # Parse original XML
        doc = described_class.parse(xml).native

        # Test namespace preservation in serialization
        result = described_class.serialize(doc)
        expect(result).to include('xmlns:soap="http://www.w3.org/2003/05/soap-envelope"')
        expect(result).to include('xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"')
        expect(result).to include('xmlns:ns="urn:example:namespace"')

        # Test xpath with namespaces
        namespaces = {
          "soap" => "http://www.w3.org/2003/05/soap-envelope",
          "ns" => "urn:example:namespace"
        }

        # Find user ID using namespaced xpath
        user_id = described_class.at_xpath(doc, "//ns:UserId", namespaces)
        expect(described_class.text_content(user_id)).to eq("user123")

        # Verify soap:Body exists
        body = described_class.at_xpath(doc, "//soap:Body", namespaces)
        expect(body).not_to be_nil

        # Verify attribute with namespace
        expect(described_class.get_attribute_value(user_id, "xsi:type")).to eq("xsi:string")
      end
    end
  end
end
