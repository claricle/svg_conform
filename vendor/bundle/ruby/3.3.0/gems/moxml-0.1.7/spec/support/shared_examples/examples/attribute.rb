# frozen_string_literal: true

RSpec.shared_examples "Attribute Examples" do
  let(:context) { Moxml.new }
  let(:doc) { context.create_document }

  describe "Attribute manipulation" do
    it "handles basic attributes" do
      element = doc.create_element("test")
      element["id"] = "123"
      element["class"] = "main"

      expect(element.to_xml).to include('id="123"')
      expect(element.to_xml).to include('class="main"')
    end

    it "handles namespaced attributes" do
      element = doc.create_element("test")
      element.add_namespace("xs", "http://www.w3.org/2001/XMLSchema")
      element["xs:type"] = "string"

      expect(element.to_xml).to include('xs:type="string"')
    end

    it "handles special characters in attributes" do
      element = doc.create_element("test")
      element["special"] = '< > & " \''

      expect(element.to_xml).to include(
        'special="&lt; &gt; &amp; &quot; \''
      )
    end

    it "removes attributes" do
      element = doc.create_element("test")
      element["temp"] = "value"
      element.remove_attribute("temp")

      expect(element.to_xml).not_to include("temp")
    end
  end
end
