# frozen_string_literal: true

# spec/moxml/errors_spec.rb
RSpec.describe "Moxml errors" do
  describe Moxml::Error do
    it "is a StandardError" do
      expect(Moxml::Error.new).to be_a(StandardError)
    end
  end

  describe Moxml::ParseError do
    it "includes line and column information" do
      error = Moxml::ParseError.new("Invalid XML", line: 5, column: 10)
      expect(error.line).to eq(5)
      expect(error.column).to eq(10)
      expect(error.message).to eq("Invalid XML")
    end

    it "works without line and column" do
      error = Moxml::ParseError.new("Invalid XML")
      expect(error.line).to be_nil
      expect(error.column).to be_nil
    end
  end

  describe Moxml::ValidationError do
    it "handles validation errors" do
      error = Moxml::ValidationError.new("Invalid document structure")
      expect(error.message).to eq("Invalid document structure")
    end
  end

  describe Moxml::XPathError do
    it "handles XPath errors" do
      error = Moxml::XPathError.new("Invalid XPath expression")
      expect(error.message).to eq("Invalid XPath expression")
    end
  end

  describe Moxml::NamespaceError do
    it "handles namespace errors" do
      error = Moxml::NamespaceError.new("Invalid namespace URI")
      expect(error.message).to eq("Invalid namespace URI")
    end
  end

  describe "error handling in context" do
    let(:context) { Moxml.new }

    it "raises ParseError for invalid XML" do
      expect do
        context.parse("<invalid>")
      end.to raise_error(Moxml::ParseError)
    end

    it "raises XPathError for invalid XPath" do
      doc = context.parse("<root/>")
      expect do
        doc.xpath("///")
      end.to raise_error(Moxml::XPathError)
    end

    it "raises NamespaceError for invalid namespace" do
      doc = context.parse("<root/>")

      expect do
        doc.root.add_namespace("xml", "http//invalid.com")
      end.to raise_error(Moxml::NamespaceError, "Invalid URI: http//invalid.com")
    end
  end
end
