# frozen_string_literal: true

require "spec_helper"

RSpec.describe SvgConform::References::ReferenceManifest do
  let(:manifest) { described_class.new(source_document: "test.svg") }

  describe "#initialize" do
    it "creates an empty manifest" do
      expect(manifest.source_document).to eq("test.svg")
      expect(manifest.available_ids).to be_empty
      expect(manifest.internal_references).to be_empty
      expect(manifest.external_references).to be_empty
    end
  end

  describe "#register_id" do
    it "registers ID definitions" do
      manifest.register_id("element-1", element_name: "rect", line_number: 10)

      expect(manifest.available_ids.size).to eq(1)
      expect(manifest.available_ids.first.id_value).to eq("element-1")
      expect(manifest.available_ids.first.element_name).to eq("rect")
      expect(manifest.available_ids.first.line_number).to eq(10)
    end

    it "registers multiple IDs" do
      manifest.register_id("id-1", element_name: "rect")
      manifest.register_id("id-2", element_name: "circle")

      expect(manifest.available_ids.size).to eq(2)
    end
  end

  describe "#register_reference" do
    it "separates internal and external references" do
      internal_ref = SvgConform::References::InternalFragmentReference.new(
        value: "#element-1",
        element_name: "use",
        attribute_name: "href",
      )

      external_ref = SvgConform::References::UrnReference.new(
        value: "urn:test",
        element_name: "a",
        attribute_name: "href",
      )

      manifest.register_reference(internal_ref)
      manifest.register_reference(external_ref)

      expect(manifest.internal_references.size).to eq(1)
      expect(manifest.external_references.size).to eq(1)
    end
  end

  describe "#id_defined?" do
    before do
      manifest.register_id("element-1", element_name: "rect")
      manifest.register_id("element-2", element_name: "circle")
    end

    it "returns true for defined IDs" do
      expect(manifest.id_defined?("element-1")).to be true
      expect(manifest.id_defined?("element-2")).to be true
    end

    it "returns false for undefined IDs" do
      expect(manifest.id_defined?("missing-element")).to be false
    end
  end

  describe "#references_to_id" do
    before do
      manifest.register_id("target-element", element_name: "rect")

      ref1 = SvgConform::References::InternalFragmentReference.new(
        value: "#target-element",
        element_name: "use",
        attribute_name: "href",
      )

      ref2 = SvgConform::References::InternalFragmentReference.new(
        value: "#target-element",
        element_name: "a",
        attribute_name: "href",
      )

      ref3 = SvgConform::References::InternalFragmentReference.new(
        value: "#other-element",
        element_name: "use",
        attribute_name: "href",
      )

      manifest.register_reference(ref1)
      manifest.register_reference(ref2)
      manifest.register_reference(ref3)
    end

    it "returns all references to a specific ID" do
      refs = manifest.references_to_id("target-element")
      expect(refs.size).to eq(2)
      expect(refs.all? { |r| r.target_id == "target-element" }).to be true
    end

    it "returns empty array for ID with no references" do
      refs = manifest.references_to_id("unreferenced-element")
      expect(refs).to be_empty
    end
  end

  describe "#references_by_type" do
    before do
      manifest.register_reference(
        SvgConform::References::InternalFragmentReference.new(
          value: "#id-1",
          element_name: "use",
          attribute_name: "href",
        ),
      )

      manifest.register_reference(
        SvgConform::References::UrnReference.new(
          value: "urn:test",
          element_name: "a",
          attribute_name: "href",
        ),
      )

      manifest.register_reference(
        SvgConform::References::ExternalUrlReference.new(
          value: "https://example.com",
          element_name: "a",
          attribute_name: "href",
        ),
      )
    end

    it "groups references by type" do
      by_type = manifest.references_by_type

      expect(by_type.keys).to include(
        "InternalFragmentReference",
        "UrnReference",
        "ExternalUrlReference",
      )
      expect(by_type["InternalFragmentReference"].size).to eq(1)
      expect(by_type["UrnReference"].size).to eq(1)
      expect(by_type["ExternalUrlReference"].size).to eq(1)
    end
  end

  describe "#unresolved_internal_references" do
    before do
      manifest.register_id("element-1", element_name: "rect")

      ref1 = SvgConform::References::InternalFragmentReference.new(
        value: "#element-1",
        element_name: "use",
        attribute_name: "href",
      )

      ref2 = SvgConform::References::InternalFragmentReference.new(
        value: "#missing-element",
        element_name: "use",
        attribute_name: "href",
      )

      ref3 = SvgConform::References::InternalFragmentReference.new(
        value: "#another-missing",
        element_name: "use",
        attribute_name: "href",
      )

      manifest.register_reference(ref1)
      manifest.register_reference(ref2)
      manifest.register_reference(ref3)
    end

    it "identifies references to non-existent IDs" do
      unresolved = manifest.unresolved_internal_references

      expect(unresolved.size).to eq(2)
      expect(unresolved.map(&:value)).to include("#missing-element",
                                                 "#another-missing")
      expect(unresolved.map(&:value)).not_to include("#element-1")
    end

    it "returns empty array when all references are resolved" do
      manifest2 = described_class.new
      manifest2.register_id("element-1", element_name: "rect")

      ref = SvgConform::References::InternalFragmentReference.new(
        value: "#element-1",
        element_name: "use",
        attribute_name: "href",
      )
      manifest2.register_reference(ref)

      expect(manifest2.unresolved_internal_references).to be_empty
    end
  end

  describe "#statistics" do
    before do
      manifest.register_id("id-1", element_name: "rect")
      manifest.register_id("id-2", element_name: "circle")

      manifest.register_reference(
        SvgConform::References::InternalFragmentReference.new(
          value: "#id-1",
          element_name: "use",
          attribute_name: "href",
        ),
      )

      manifest.register_reference(
        SvgConform::References::InternalFragmentReference.new(
          value: "#missing",
          element_name: "use",
          attribute_name: "href",
        ),
      )

      manifest.register_reference(
        SvgConform::References::UrnReference.new(
          value: "urn:test",
          element_name: "a",
          attribute_name: "href",
        ),
      )

      manifest.register_reference(
        SvgConform::References::ExternalUrlReference.new(
          value: "https://example.com",
          element_name: "a",
          attribute_name: "href",
        ),
      )
    end

    it "provides comprehensive statistics" do
      stats = manifest.statistics

      expect(stats[:total_ids]).to eq(2)
      expect(stats[:total_references]).to eq(4)
      expect(stats[:internal_references]).to eq(2)
      expect(stats[:external_references]).to eq(2)
      expect(stats[:unresolved_internal]).to eq(1)
      expect(stats[:references_by_type]["InternalFragmentReference"]).to eq(2)
      expect(stats[:references_by_type]["UrnReference"]).to eq(1)
      expect(stats[:references_by_type]["ExternalUrlReference"]).to eq(1)
    end
  end

  describe "#to_h" do
    before do
      manifest.register_id("test-id", element_name: "rect", line_number: 5)

      manifest.register_reference(
        SvgConform::References::InternalFragmentReference.new(
          value: "#test-id",
          element_name: "use",
          attribute_name: "href",
          line_number: 10,
        ),
      )
    end

    it "exports manifest as hash" do
      hash = manifest.to_h

      expect(hash[:source_document]).to eq("test.svg")
      expect(hash[:available_ids]).to be_an(Array)
      expect(hash[:internal_references]).to be_an(Array)
      expect(hash[:external_references]).to be_an(Array)
      expect(hash[:statistics]).to be_a(Hash)
    end
  end

  describe "export formats" do
    before do
      manifest.register_id("test-id", element_name: "rect")
      manifest.register_reference(
        SvgConform::References::UrnReference.new(
          value: "urn:test",
          element_name: "a",
          attribute_name: "href",
        ),
      )
    end

    it "exports as YAML" do
      yaml = manifest.to_yaml
      expect(yaml).to be_a(String)
      expect(yaml).to include("test.svg")
      expect(yaml).to include("test-id")
    end

    it "exports as JSON" do
      json = manifest.to_json
      expect(json).to be_a(String)
      parsed = JSON.parse(json)
      expect(parsed["source_document"]).to eq("test.svg")
    end
  end
end
