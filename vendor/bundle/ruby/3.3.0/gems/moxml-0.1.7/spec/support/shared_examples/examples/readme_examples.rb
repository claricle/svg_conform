# frozen_string_literal: true

RSpec.shared_examples "README Examples" do
  describe "Basic document creation" do
    it "builds document as shown in README" do
      doc = Moxml.new.create_document

      # Add XML declaration
      doc.add_child(doc.create_declaration("1.0", "UTF-8"))

      # Create root element with namespace
      root = doc.create_element("book")
      root.add_namespace("dc", "http://purl.org/dc/elements/1.1/")
      doc.add_child(root)

      # Add content
      title = doc.create_element("dc:title")
      title.text = "XML Processing with Ruby"
      root.add_child(title)

      expect(doc.to_xml).to include(
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<book xmlns:dc="http://purl.org/dc/elements/1.1/">',
        "<dc:title>XML Processing with Ruby</dc:title>",
        "</book>"
      )
    end
  end

  describe "Using the builder pattern" do
    it "builds a correct document" do
      doc = Moxml::Builder.new(Moxml.new).build do
        declaration version: "1.0", encoding: "UTF-8"

        element "library", xmlns: "http://example.org/library" do
          element "book" do
            element "title" do
              text "Ruby Programming"
            end

            element "author" do
              text "Jane Smith"
            end

            comment "Publication details"
            element "published", year: "2024"

            cdata "<custom>metadata</custom>"
          end
        end
      end

      expect(doc.to_xml).to include(
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<library xmlns="http://example.org/library">',
        "<title>Ruby Programming</title>",
        "<!--Publication details-->",
        '<published year="2024"></published>',
        "<![CDATA[<custom>metadata</custom>]]>",
        "</book>"
      )
    end
  end

  describe "Direct document manipulation" do
    it "builds document with all features" do
      doc = Moxml.new.create_document

      # Add declaration
      doc.add_child(doc.create_declaration("1.0", "UTF-8"))

      # Create root with namespace
      root = doc.create_element("library")
      root.add_namespace(nil, "http://example.org/library")
      root.add_namespace("dc", "http://purl.org/dc/elements/1.1/")
      doc.add_child(root)

      # Add books
      %w[Ruby XML].each do |title|
        book = doc.create_element("book")
        book["id"] = "b1-#{title}"

        # Add mixed content
        book.add_child(doc.create_comment("Book details"))
        dc_title = doc.create_element("dc:title")
        dc_title.text = title
        book.add_child(dc_title)

        # Add description
        desc = doc.create_element("description")
        desc.add_child(doc.create_cdata("About #{title}..."))
        book.add_child(desc)

        root.add_child(book)
      end

      expect(doc.to_xml).to include(
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<library xmlns="http://example.org/library" xmlns:dc="http://purl.org/dc/elements/1.1/">',
        '<book id="b1-Ruby">',
        "<!--Book details-->",
        "<dc:title>Ruby</dc:title>",
        "<![CDATA[About Ruby...]]>",
        "<dc:title>XML</dc:title>",
        "<![CDATA[About XML...]]>"
      )
    end
  end

  describe "Error handling example" do
    it "handles errors as shown in README" do
      context = Moxml.new
      pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

      expect do
        context.parse("<invalid>")
      end.to raise_error(Moxml::ParseError)

      expect do
        doc = context.parse("<root/>")
        root = doc.root
        root.add_namespace("n", "wrong.url")
      end.to raise_error(Moxml::NamespaceError)

      expect do
        doc = context.parse("<root/>")
        element = doc.create_element("wrong,name")
        doc.add_child(element)
      end.to raise_error(Moxml::ValidationError)

      doc = context.parse("<root/>")
      expect do
        doc.xpath("///")
      end.to raise_error(Moxml::XPathError)
    end
  end

  describe "Thread safety example" do
    it "processes XML in thread-safe manner" do
      processor = Class.new do
        def initialize
          @mutex = Mutex.new
          @context = Moxml.new
        end

        def process(xml)
          @mutex.synchronize do
            doc = @context.parse(xml)
            # Modify document
            element = doc.create_element("test")
            doc.root.add_child(element)
            doc.root.children.first.remove
            doc.to_xml
          end
        end
      end.new

      result = processor.process("<root/>")
      expect(result).to include("<root></root>")
    end
  end
end
