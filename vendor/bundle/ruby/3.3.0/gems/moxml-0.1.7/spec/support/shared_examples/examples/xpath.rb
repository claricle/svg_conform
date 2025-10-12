# frozen_string_literal: true

RSpec.shared_examples "XPath Examples" do
  let(:context) { Moxml.new }

  describe "XPath querying" do
    let(:doc) do
      context.parse(<<~XML)
        <root xmlns:dc="http://purl.org/dc/elements/1.1/">
          <book id="1">
            <dc:title>First</dc:title>
          </book>
          <book id="2">
            <dc:title>Second</dc:title>
          </book>
        </root>
      XML
    end

    it "finds nodes by XPath" do
      pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

      books = doc.xpath("//book")
      expect(books.size).to eq(2)
      expect(books.map { _1["id"] }).to eq(%w[1 2])
    end

    it "finds nodes with namespaces" do
      pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

      titles = doc.xpath("//dc:title",
                         "dc" => "http://purl.org/dc/elements/1.1/")
      expect(titles.map(&:text)).to eq(%w[First Second])
    end

    it "finds nodes by attributes" do
      pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

      book = doc.at_xpath('//book[@id="2"]')
      expect(book).not_to be_nil
      title = book.at_xpath(".//dc:title",
                            "dc" => "http://purl.org/dc/elements/1.1/")
      expect(title.text).to eq("Second")
    end

    it "finds nested attributes efficiently" do
      pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox
      # More efficient - specific path
      titles1 = doc.xpath("//book/dc:title")

      # Less efficient - requires full document scan
      titles2 = doc.xpath("//dc:title")

      # Most efficient - direct child access
      titles3 = doc.root.xpath("./*/dc:title", "dc" => "http://purl.org/dc/elements/1.1/")

      # Chain queries
      nodes = doc.xpath("//book").map do |book|
        # Each book is a mapped Moxml::Element
        book.at_xpath(".//dc:title", "dc" => "http://purl.org/dc/elements/1.1/").native
      end
      titles4 = ::Moxml::NodeSet.new(nodes, doc.context)

      expect(titles1.count).to eq(2)
      expect(titles1).to eq(titles2)
      expect(titles1).to eq(titles3)
      expect(titles1).to eq(titles4)
    end
  end
end
