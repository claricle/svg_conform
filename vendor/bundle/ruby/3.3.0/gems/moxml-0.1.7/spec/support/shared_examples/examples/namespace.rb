# frozen_string_literal: true

RSpec.shared_examples "Namespace Examples" do
  let(:context) { Moxml.new }

  describe "Namespace handling" do
    it "handles default namespace" do
      doc = context.create_document
      root = doc.create_element("root")
      root.add_namespace(nil, "http://example.org")
      doc.add_child(root)

      expect(doc.to_xml).to include('xmlns="http://example.org"')
    end

    it "handles prefixed namespaces" do
      doc = context.create_document
      root = doc.create_element("root")
      root.add_namespace("dc", "http://purl.org/dc/elements/1.1/")
      doc.add_child(root)

      title = doc.create_element("dc:title")
      title.add_child(doc.create_text("Test"))
      root.add_child(title)

      expect(doc.to_xml).to include(
        'xmlns:dc="http://purl.org/dc/elements/1.1/"',
        "<dc:title>Test</dc:title>"
      )
    end

    it "handles namespace inheritance" do
      doc = context.create_document
      root = doc.create_element("root")
      root.add_namespace("ns", "http://example.org")
      doc.add_child(root)

      child = doc.create_element("ns:child")
      root.add_child(child)
      grandchild = doc.create_element("ns:grandchild")
      child.add_child(grandchild)

      expect(doc.to_xml).to include(
        "<ns:child>",
        "<ns:grandchild>"
      )
    end

    it "handles namespace overriding" do
      doc = context.create_document
      root = doc.create_element("root")
      root.add_namespace("ns", "http://example.org/1")
      doc.add_child(root)

      child = doc.create_element("child")
      child.add_namespace("ns", "http://example.org/2")
      root.add_child(child)

      expect(doc.to_xml).to include(
        'xmlns:ns="http://example.org/1"',
        'xmlns:ns="http://example.org/2"'
      )
    end
  end
end
