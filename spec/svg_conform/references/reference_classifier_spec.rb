# frozen_string_literal: true

require "spec_helper"

RSpec.describe SvgConform::References::ReferenceClassifier do
  describe ".classify" do
    it "classifies internal fragment references" do
      ref = described_class.classify(
        "#element-id",
        element_name: "use",
        attribute_name: "href",
        line_number: 10
      )

      expect(ref).to be_a(SvgConform::References::InternalFragmentReference)
      expect(ref.value).to eq("#element-id")
      expect(ref.internally_validatable?).to be true
      expect(ref.requires_consumer_validation?).to be false
      expect(ref.target_id).to eq("element-id")
    end

    it "classifies URN references" do
      ref = described_class.classify(
        "urn:ietf:rfc:7996",
        element_name: "a",
        attribute_name: "href",
        line_number: 42
      )

      expect(ref).to be_a(SvgConform::References::UrnReference)
      expect(ref.value).to eq("urn:ietf:rfc:7996")
      expect(ref.internally_validatable?).to be false
      expect(ref.requires_consumer_validation?).to be true
      expect(ref.namespace).to eq("ietf")
    end

    it "classifies external URL references (http)" do
      ref = described_class.classify(
        "http://www.example.com/resource",
        element_name: "a",
        attribute_name: "href"
      )

      expect(ref).to be_a(SvgConform::References::ExternalUrlReference)
      expect(ref.requires_consumer_validation?).to be true
      expect(ref.protocol).to eq("http")
    end

    it "classifies external URL references (https)" do
      ref = described_class.classify(
        "https://www.example.com/resource",
        element_name: "a",
        attribute_name: "href"
      )

      expect(ref).to be_a(SvgConform::References::ExternalUrlReference)
      expect(ref.requires_consumer_validation?).to be true
      expect(ref.protocol).to eq("https")
    end

    it "classifies data URI references" do
      ref = described_class.classify(
        "data:image/png;base64,iVBORw0KGgo=",
        element_name: "image",
        attribute_name: "href"
      )

      expect(ref).to be_a(SvgConform::References::DataUriReference)
      expect(ref.internally_validatable?).to be true
      expect(ref.media_type).to eq("image/png")
    end

    it "classifies relative path references starting with ./" do
      ref = described_class.classify(
        "./other-doc.svg#element",
        element_name: "use",
        attribute_name: "href"
      )

      expect(ref).to be_a(SvgConform::References::RelativePathReference)
      expect(ref.requires_consumer_validation?).to be true
      expect(ref.has_fragment?).to be true
      expect(ref.path_component).to eq("./other-doc.svg")
      expect(ref.fragment_component).to eq("element")
    end

    it "classifies relative path references starting with /" do
      ref = described_class.classify(
        "/absolute/path.svg",
        element_name: "use",
        attribute_name: "href"
      )

      expect(ref).to be_a(SvgConform::References::RelativePathReference)
      expect(ref.requires_consumer_validation?).to be true
    end

    it "classifies bare paths as relative references" do
      ref = described_class.classify(
        "other-doc.svg",
        element_name: "use",
        attribute_name: "href"
      )

      expect(ref).to be_a(SvgConform::References::RelativePathReference)
      expect(ref.requires_consumer_validation?).to be true
    end

    it "returns nil for nil value" do
      ref = described_class.classify(
        nil,
        element_name: "use",
        attribute_name: "href"
      )

      expect(ref).to be_nil
    end

    it "returns nil for empty value" do
      ref = described_class.classify(
        "",
        element_name: "use",
        attribute_name: "href"
      )

      expect(ref).to be_nil
    end

    it "captures line and column information" do
      ref = described_class.classify(
        "#element-id",
        element_name: "use",
        attribute_name: "href",
        line_number: 42,
        column_number: 15
      )

      expect(ref.line_number).to eq(42)
      expect(ref.column_number).to eq(15)
    end
  end
end