# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Reference Manifest Integration" do
  let(:validator) { SvgConform::Validator.new(profile: "metanorma") }

  describe "complete reference manifest generation" do
    let(:svg_content) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" version="1.2" baseProfile="tiny" viewBox="0 0 100 100">
          <rect id="rect-1" x="0" y="0" width="100" height="100"/>
          <circle id="circle-1" cx="50" cy="50" r="25"/>
          <use href="#rect-1"/>
          <use href="#missing-element"/>
          <a href="urn:ietf:rfc:7996">RFC 7996</a>
          <a href="https://www.example.com">Example</a>
          <image href="data:image/png;base64,iVBORw0KGgo=" x="0" y="0" width="10" height="10"/>
          <image href="./other.svg#fragment" x="0" y="0" width="10" height="10"/>
        </svg>
      SVG
    end

    it "builds complete manifest with IDs and references" do
      result = validator.validate(svg_content)
      manifest = result.reference_manifest

      # Check IDs are collected
      expect(manifest.available_ids.size).to eq(2)
      expect(manifest.id_defined?("rect-1")).to be true
      expect(manifest.id_defined?("circle-1")).to be true

      # Check references are collected
      expect(manifest.internal_references.size).to eq(3) # 2 uses + 1 data URI
      expect(manifest.external_references.size).to eq(3) # 1 urn + 1 https + 1 relative

      # Check statistics
      stats = manifest.statistics
      expect(stats[:total_ids]).to eq(2)
      expect(stats[:total_references]).to eq(6)
      expect(stats[:unresolved_internal]).to eq(1)
    end

    it "identifies unresolved internal references" do
      result = validator.validate(svg_content)
      manifest = result.reference_manifest

      unresolved = manifest.unresolved_internal_references
      expect(unresolved.size).to eq(1)
      expect(unresolved.first.value).to eq("#missing-element")
    end

    it "groups references by type" do
      result = validator.validate(svg_content)
      manifest = result.reference_manifest

      by_type = manifest.references_by_type
      expect(by_type["InternalFragmentReference"].size).to eq(2)  # 2 uses
      expect(by_type["UrnReference"].size).to eq(1)
      expect(by_type["ExternalUrlReference"].size).to eq(1)
      expect(by_type["DataUriReference"].size).to eq(1)
      expect(by_type["RelativePathReference"].size).to eq(1)
    end

    it "validates internal references but not external ones" do
      result = validator.validate(svg_content)

      # Should have errors for unresolved internal reference
      internal_ref_errors = result.errors.select do |e|
        e.message.include?("missing-element")
      end
      expect(internal_ref_errors).not_to be_empty

      # Should NOT have errors for external references
      external_ref_errors = result.errors.select do |e|
        e.message.include?("urn:") || e.message.include?("https://")
      end
      expect(external_ref_errors).to be_empty
    end
  end

  describe "ValidationResult convenience methods" do
    let(:svg_content) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" version="1.2" baseProfile="tiny" viewBox="0 0 100 100">
          <rect id="target"/>
          <use href="#target"/>
          <a href="urn:test">Test</a>
        </svg>
      SVG
    end

    it "provides convenient accessors" do
      result = validator.validate(svg_content)

      expect(result.available_ids.size).to eq(1)
      expect(result.internal_references.size).to eq(1)
      expect(result.external_references.size).to eq(1)
      expect(result.has_external_references?).to be true
      expect(result.unresolved_internal_references).to be_empty
    end

    it "exports manifest in different formats" do
      result = validator.validate(svg_content)

      yaml_export = result.export_manifest(format: :yaml)
      expect(yaml_export).to be_a(String)
      expect(yaml_export).to include("target")

      json_export = result.export_manifest(format: :json)
      expect(json_export).to be_a(String)
      parsed = JSON.parse(json_export)
      expect(parsed["available_ids"]).to be_an(Array)
    end
  end

  describe "cross-document reference scenario" do
    let(:svg_with_external_fragment) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" version="1.2" baseProfile="tiny" viewBox="0 0 100 100">
          <rect id="local-element"/>
          <use href="#local-element"/>
          <use href="other-doc.svg#external-element"/>
        </svg>
      SVG
    end

    it "classifies external fragment references correctly" do
      result = validator.validate(svg_with_external_fragment)
      manifest = result.reference_manifest

      # Local fragment should be internal
      expect(manifest.internal_references.size).to eq(1)
      expect(manifest.internal_references.first.value).to eq("#local-element")

      # External fragment should be external (requires consumer validation)
      expect(manifest.external_references.size).to eq(1)
      external_ref = manifest.external_references.first
      expect(external_ref).to be_a(SvgConform::References::RelativePathReference)
      expect(external_ref.has_fragment?).to be true
      expect(external_ref.fragment_component).to eq("external-element")
    end
  end

  describe "reference statistics and querying" do
    let(:complex_svg) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" version="1.2" baseProfile="tiny" viewBox="0 0 100 100">
          <defs>
            <linearGradient id="grad1">
              <stop offset="0%" stop-color="red"/>
            </linearGradient>
            <clipPath id="clip1">
              <rect x="0" y="0" width="50" height="50"/>
            </clipPath>
          </defs>
          <rect id="rect1" fill="url(#grad1)" clip-path="url(#clip1)"/>
          <use href="#rect1"/>
          <use href="#rect1"/>
          <a href="https://example.com">Link</a>
        </svg>
      SVG
    end

    it "tracks multiple references to same ID" do
      result = validator.validate(complex_svg)
      manifest = result.reference_manifest

      rect1_refs = manifest.references_to_id("rect1")
      expect(rect1_refs.size).to eq(2)
    end

    it "provides accurate statistics" do
      result = validator.validate(complex_svg)
      stats = result.reference_statistics

      expect(stats[:total_ids]).to eq(3) # grad1, clip1, rect1
      expect(stats[:internal_references]).to eq(2) # 2 uses
      expect(stats[:external_references]).to eq(1) # 1 https
      expect(stats[:unresolved_internal]).to eq(0)
    end
  end

  describe "to_h includes reference manifest" do
    let(:svg_content) do
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" version="1.2" baseProfile="tiny" viewBox="0 0 100 100">
          <rect id="test"/>
          <a href="urn:test">Test</a>
        </svg>
      SVG
    end

    it "includes manifest in hash representation" do
      result = validator.validate(svg_content)
      hash = result.to_h

      expect(hash).to have_key(:reference_manifest)
      manifest_data = hash[:reference_manifest]
      expect(manifest_data).to have_key(:available_ids)
      expect(manifest_data).to have_key(:internal_references)
      expect(manifest_data).to have_key(:external_references)
      expect(manifest_data).to have_key(:statistics)
    end
  end
end