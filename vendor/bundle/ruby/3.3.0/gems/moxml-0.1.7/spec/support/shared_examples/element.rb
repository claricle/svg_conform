# frozen_string_literal: true

RSpec.shared_examples "Moxml::Element" do
  describe Moxml::Element do
    let(:context) { Moxml.new }
    let(:doc) { context.create_document }
    let(:element) { doc.create_element("test") }

    it "identifies as element node" do
      expect(element).to be_element
    end

    describe "name handling" do
      it "gets name" do
        expect(element.name).to eq("test")
      end

      it "sets name" do
        element.name = "new_name"
        expect(element.name).to eq("new_name")
      end
    end

    describe "attributes" do
      before { element["id"] = "123" }

      it "sets attribute" do
        expect(element["id"]).to eq("123")
      end

      it "gets attribute" do
        expect(element.attribute("id")).to be_a(Moxml::Attribute)
        expect(element.attribute("id").value).to eq("123")
      end

      it "gets all attributes" do
        element["class"] = "test"
        expect(element.attributes.size).to eq(2)
        expect(element.attributes.map(&:name)).to contain_exactly("id", "class")
      end

      it "removes attribute" do
        element.remove_attribute("id")
        expect(element["id"]).to be_nil
      end

      it "handles special characters" do
        element["special"] = '< > & " \''
        expect(element.to_xml).to include('special="&lt; &gt; &amp; &quot; \'')
      end
    end

    describe "namespaces" do
      it "adds namespace" do
        element.add_namespace("x", "http://example.org")
        expect(element.namespaces.size).to eq(1)
        expect(element.namespaces.first.prefix).to eq("x")
        expect(element.namespaces.first.uri).to eq("http://example.org")
      end

      it "sets namespace" do
        ns = element.add_namespace("x", "http://example.org").namespaces.first
        element.namespace = ns
        expect(element.namespace).to eq(ns)
      end

      it "adds default namespace" do
        element.add_namespace(nil, "http://example.org")
        expect(element.namespace.prefix).to be_nil
        expect(element.namespace.uri).to eq("http://example.org")
      end
    end

    describe "content manipulation" do
      it "sets text content" do
        element.text = "content"
        expect(element.text).to eq("content")
      end

      it "appends text" do
        element.text = "first"
        element.add_child("second")
        expect(element.text).to eq("firstsecond")
      end

      it "sets inner XML" do
        element.inner_xml = "<child>text</child>"
        expect(element.children.size).to eq(1)
        expect(element.children.first.name).to eq("child")
        expect(element.children.first.text).to eq("text")
      end
    end

    describe "node manipulation" do
      it "adds child element" do
        child = doc.create_element("child")
        element.add_child(child)
        expect(element.children.first).to eq(child)
      end

      it "adds child text" do
        element.add_child("text")
        expect(element.text).to eq("text")
      end

      it "adds mixed content" do
        element.add_child("text")
        element.add_child(doc.create_element("child"))
        element.add_child("more")
        expect(element.to_xml).to include("text<child></child>more")
      end
    end

    describe "complex element structures" do
      it "creates nested paragraphs without namespaces" do
        outer_p = doc.create_element("p")
        inner_p = doc.create_element("p")
        inner_p.add_child("Some text inside paragraph")
        outer_p.add_child(inner_p)

        expect(outer_p.to_xml).to include("<p>Some text inside paragraph</p>")
      end

      it "does not return text of child elements in root text" do
        outer_p = doc.create_element("p")
        inner_p = doc.create_element("p")
        inner_p.add_child("Some text inside paragraph")
        outer_p.add_child(inner_p)
        expect(outer_p.inner_text).to eq("")
        expect(inner_p.text).to include("Some text inside paragraph")
      end
    end
  end
end
