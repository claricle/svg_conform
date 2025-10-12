# frozen_string_literal: true

RSpec.shared_examples "Moxml::Namespace" do
  describe Moxml::Namespace do
    let(:context) { Moxml.new }
    let(:doc) { context.create_document }
    let(:element) { doc.create_element("test") }

    describe "creation" do
      it "creates namespace with prefix" do
        element.add_namespace("xs", "http://www.w3.org/2001/XMLSchema")
        ns = element.namespaces.first

        expect(ns).to be_namespace
        expect(ns.prefix).to eq("xs")
        expect(ns.uri).to eq("http://www.w3.org/2001/XMLSchema")
      end

      it "creates default namespace" do
        element.add_namespace(nil, "http://example.org")
        ns = element.namespaces.first

        expect(ns.prefix).to be_nil
        expect(ns.uri).to eq("http://example.org")
      end

      it "validates URI" do
        expect do
          element.add_namespace("xs", "invalid uri")
        end.to raise_error(Moxml::NamespaceError, "Invalid URI: invalid uri")
      end
    end

    describe "string representation" do
      it "formats prefixed namespace" do
        element.add_namespace("xs", "http://www.w3.org/2001/XMLSchema")
        expect(element.namespaces.first.to_s).to eq('xmlns:xs="http://www.w3.org/2001/XMLSchema"')
      end

      it "formats default namespace" do
        element.add_namespace(nil, "http://example.org")
        expect(element.namespaces.first.to_s).to eq('xmlns="http://example.org"')
      end

      it "renders the same xml - a readme example" do
        # chainable operations
        element
          .add_namespace("dc", "http://purl.org/dc/elements/1.1/")
          .add_child(doc.create_text("content"))

        # clear node type checking
        node = doc.create_element("test")
        if node.element?
          node.add_namespace("dc", "http://purl.org/dc/elements/1.1/")
          node.add_child(doc.create_text("content"))
        end

        expect(element.to_xml).to eq(node.to_xml)
      end
    end

    describe "equality" do
      let(:ns1) { element.add_namespace("xs", "http://www.w3.org/2001/XMLSchema").namespaces.last }
      let(:ns2) { element.add_namespace("xs", "http://www.w3.org/2001/XMLSchema").namespaces.last }
      let(:ns3) { element.add_namespace("xsi", "http://www.w3.org/2001/XMLSchema-instance").namespaces.last }

      it "compares namespaces" do
        expect(ns1).to eq(ns2)
        expect(ns1).not_to eq(ns3)
      end

      it "compares with different elements" do
        other_element = doc.create_element("other")
        other_ns = other_element.add_namespace("xs", "http://www.w3.org/2001/XMLSchema").namespaces.first
        expect(ns1).to eq(other_ns)
      end
    end

    describe "inheritance" do
      it "does not inherit parent namespaces" do
        # https://stackoverflow.com/a/67347081
        root = doc.create_element("root")
        root.namespace = { "xs" => "http://www.w3.org/2001/XMLSchema" }
        child = doc.create_element("child")
        root.add_child(child)

        expect(child.namespace).to be_nil
      end

      it "inherits default parent namespaces" do
        root = doc.create_element("root")
        root.namespace = { nil => "http://www.w3.org/2001/XMLSchema" }
        child = doc.create_element("child")
        root.add_child(child)

        expect(child.namespace.prefix).to be_nil
        expect(child.namespace.uri).to eq("http://www.w3.org/2001/XMLSchema")
      end

      it "overrides parent namespace" do
        root = doc.create_element("root")
        root.namespace = { "ns" => "http://example.org/1" }
        child = doc.create_element("child")
        child.namespace = { "ns" => "http://example.org/2" }
        root.add_child(child)

        expect(root.namespace.uri).to eq("http://example.org/1")
        expect(child.namespace.uri).to eq("http://example.org/2")
      end
    end
  end
end
