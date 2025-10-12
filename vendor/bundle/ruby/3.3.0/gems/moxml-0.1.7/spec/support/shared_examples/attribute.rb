# frozen_string_literal: true

RSpec.shared_examples "Moxml::Attribute" do
  describe Moxml::Attribute do
    let(:context) { Moxml.new }
    let(:doc) { context.create_document }
    let(:element) { doc.create_element("test") }

    describe "creation and access" do
      before do
        element["test"] = "value"
      end

      let(:attribute) { element.attributes.first }

      it "creates attribute" do
        expect(attribute).to be_a(described_class)
        expect(attribute).to be_attribute
      end

      it "gets name" do
        expect(attribute.name).to eq("test")
      end

      it "gets value" do
        expect(attribute.value).to eq("value")
      end

      it "sets name" do
        attribute.name = "new_name"
        expect(attribute.name).to eq("new_name")
        expect(element["new_name"]).to eq("value")
        expect(element["test"]).to be_nil
      end

      it "sets value" do
        attribute.value = "new_value"
        expect(attribute.value).to eq("new_value")
        expect(element["test"]).to eq("new_value")
      end
    end

    describe "namespaces" do
      before do
        element.add_namespace("ns", "http://example.org")
      end

      it "handles namespaced attributes" do
        element["ns:attr"] = "value"
        attribute = element.attributes.first

        expect(attribute.namespace).not_to be_nil
        expect(attribute.namespace.prefix).to eq("ns")
        expect(attribute.namespace.uri).to eq("http://example.org")
      end

      it "changes attribute namespace" do
        element["attr"] = "value"
        attribute = element.attributes.first

        element.add_namespace("other", "http://other.org")
        new_ns = element.namespaces.last
        attribute.namespace = new_ns

        expect(attribute.namespace.prefix).to eq("other")
        expect(attribute.to_s).to eq('other:attr="value"')
      end
    end

    describe "manipulation" do
      before do
        element["test"] = "value"
      end

      let(:attribute) do
        element.attributes.first
      end

      it "removes attribute" do
        attribute.remove
        expect(element["test"]).to be_nil
        expect(element.attributes).to be_empty
      end

      it "handles special characters in values" do
        attribute.value = "< & > ' \""
        expect(attribute.to_s).to eq('test="< & > \' ""')
      end
    end

    describe "#to_s" do
      it "formats regular attribute" do
        element["test"] = "value"
        expect(element.attributes.first.to_s).to eq('test="value"')
      end

      it "formats namespaced attribute" do
        element.add_namespace("ns", "http://example.org")
        element["ns:test"] = "value"
        expect(element.attributes.first.to_s).to eq('ns:test="value"')
      end
    end

    describe "equality" do
      it "compares attributes" do
        element["test"] = "value"
        attr1 = element.attributes.first

        element2 = doc.create_element("other")
        element2["test"] = "value"
        attr2 = element2.attributes.first

        element3 = doc.create_element("other")
        element3["test"] = "different"
        attr3 = element3.attributes.first

        expect(attr1).to eq(attr2)
        expect(attr1).not_to eq(attr3)
      end

      it "compares attributes with namespaces" do
        element.add_namespace("ns", "http://example.org")
        element["ns:test"] = "value"
        attr1 = element.attributes.first

        element2 = doc.create_element("other")
        element2.add_namespace("ns", "http://example.org")
        element2["ns:test"] = "value"
        attr2 = element2.attributes.first

        expect(attr1).to eq(attr2)
      end
    end

    describe "edge cases" do
      it "handles empty values" do
        element["empty"] = ""
        attribute = element.attributes.first
        expect(attribute.value).to eq("")
        expect(attribute.to_s).to eq('empty=""')
      end

      it "handles nil values" do
        element["nil"] = nil
        attribute = element.attributes.first
        expect(attribute.value).to eq("")
        expect(attribute.to_s).to eq('nil=""')
      end

      it "handles numeric values" do
        element["num"] = 123
        attribute = element.attributes.first
        expect(attribute.value).to eq("123")
        expect(attribute.to_s).to eq('num="123"')
      end

      it "handles boolean values" do
        element["bool"] = true
        attribute = element.attributes.first
        expect(attribute.value).to eq("true")
        expect(attribute.to_s).to eq('bool="true"')
      end
    end
  end
end
