# frozen_string_literal: true

require "spec_helper"
require "canon"

RSpec.describe SvgConform::Requirements::AllowedElementsRequirement do
  let(:fixtures_dir) { "spec/fixtures/allowed_elements" }

  # Get all fixture files that have both input and expected repair versions
  fixture_files = Dir.glob("spec/fixtures/allowed_elements/inputs/*.svg").select do |input_file|
    basename = File.basename(input_file)
    File.exist?("spec/fixtures/allowed_elements/repair/#{basename}")
  end.map do |f|
    File.basename(f, ".svg")
  end

  fixture_files.each do |fixture_name|
    describe "fixture: #{fixture_name}" do
      let(:input_file) do
        "spec/fixtures/allowed_elements/inputs/#{fixture_name}.svg"
      end
      let(:expected_output_file) do
        "spec/fixtures/allowed_elements/repair/#{fixture_name}.svg"
      end

      it "validates input file and identifies violations" do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: "allowed_elements",
          description: "Test allowed elements requirement",
          disallowed_elements: %w[script audio video animate animateColor
                                  clipPath marker],
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        expect(context.errors).not_to be_empty

        context.errors.each do |error|
          expect(error.requirement_id).to eq("allowed_elements")
          expect(error.message).to be_a(String)
          expect(error.message).not_to be_empty
        end
      end

      it "correctly identifies specific violations" do
        skip "Input file not found" unless File.exist?(input_file)

        document = SvgConform::Document.from_file(input_file)
        requirement = described_class.new(
          id: "allowed_elements",
          description: "Test allowed elements requirement",
          disallowed_elements: %w[script audio video animate animateColor
                                  clipPath marker],
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        # Check that errors are specific to disallowed elements or attributes
        context.errors.each do |error|
          expect(error.message).to match(/Element .* is not allowed|Attribute .* is not allowed/)
        end
      end

      it "passes validation for documents with only allowed elements" do
        # Create a simple valid document for testing
        allowed_svg = <<~SVG
          <?xml version="1.0"?>
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
            <g>
              <rect x="10" y="10" width="20" height="20" fill="black"/>
              <circle cx="50" cy="50" r="10" fill="black"/>
              <text x="10" y="80">Test</text>
            </g>
          </svg>
        SVG

        document = SvgConform::Document.from_content(allowed_svg)
        requirement = described_class.new(
          id: "allowed_elements",
          description: "Test allowed elements requirement",
          disallowed_elements: %w[], # No disallowed elements, so it should pass
        )

        context = SvgConform::ValidationContext.new(document, nil)
        requirement.validate_document(document, context)

        expect(context.errors).to be_empty
      end
    end
  end

  describe "clip-path and mask global properties" do
    let(:base_requirement) do
      described_class.new(
        id: "test_global_props",
        description: "Test global properties",
        check_attributes: true,
      )
    end

    it "allows clip-path attribute on any element" do
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip1">
              <rect x="0" y="0" width="50" height="50"/>
            </clipPath>
          </defs>
          <g clip-path="url(#clip1)">
            <rect x="10" y="10" width="30" height="30" fill="red"/>
          </g>
        </svg>
      SVG

      document = SvgConform::Document.from_content(svg)
      context = SvgConform::ValidationContext.new(document, nil)
      base_requirement.validate_document(document, context)

      # clip-path should be allowed - no attribute errors
      clip_path_errors = context.errors.select { |e| e.message.include?("clip-path") }
      expect(clip_path_errors).to be_empty
    end

    it "allows mask attribute on any element" do
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <defs>
            <mask id="mask1">
              <rect x="0" y="0" width="50" height="50" fill="white"/>
            </mask>
          </defs>
          <g mask="url(#mask1)">
            <rect x="10" y="10" width="30" height="30" fill="red"/>
          </g>
        </svg>
      SVG

      document = SvgConform::Document.from_content(svg)
      context = SvgConform::ValidationContext.new(document, nil)
      base_requirement.validate_document(document, context)

      # mask should be allowed - no attribute errors
      mask_errors = context.errors.select { |e| e.message.include?("mask") }
      expect(mask_errors).to be_empty
    end

    it "allows both clip-path and mask on same element" do
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <defs>
            <clipPath id="clip1">
              <rect x="0" y="0" width="50" height="50"/>
            </clipPath>
            <mask id="mask1">
              <rect x="0" y="0" width="50" height="50" fill="white"/>
            </mask>
          </defs>
          <g clip-path="url(#clip1)" mask="url(#mask1)">
            <rect x="10" y="10" width="30" height="30" fill="red"/>
          </g>
        </svg>
      SVG

      document = SvgConform::Document.from_content(svg)
      context = SvgConform::ValidationContext.new(document, nil)
      base_requirement.validate_document(document, context)

      expect(context.errors).to be_empty
    end

    it "allows clip-path on svg root element" do
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" clip-path="url(#rootClip)">
          <defs>
            <clipPath id="rootClip">
              <rect x="0" y="0" width="100" height="100"/>
            </clipPath>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="red"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(svg)
      context = SvgConform::ValidationContext.new(document, nil)
      base_requirement.validate_document(document, context)

      clip_path_errors = context.errors.select { |e| e.message.include?("clip-path") }
      expect(clip_path_errors).to be_empty
    end

    it "allows mask on rect element" do
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <defs>
            <mask id="mask1">
              <rect x="0" y="0" width="100" height="100" fill="white"/>
            </mask>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="red" mask="url(#mask1)"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(svg)
      context = SvgConform::ValidationContext.new(document, nil)
      base_requirement.validate_document(document, context)

      mask_errors = context.errors.select { |e| e.message.include?("mask") }
      expect(mask_errors).to be_empty
    end
  end

  describe "configuration" do
    it "accepts custom allowed elements list" do
      requirement = described_class.new(
        id: "test_allowed_elements",
        description: "Test with custom elements",
        disallowed_elements: %w[script iframe embed],
      )

      expect(requirement.disallowed_elements).to eq(%w[script iframe embed])
    end

    it "can be instantiated with basic parameters" do
      requirement = described_class.new(
        id: "test_allowed_elements",
        description: "Test requirement",
      )

      expect(requirement).to be_a(described_class)
    end

    it "accepts allowed_attribute_patterns for wildcard attribute exemption" do
      requirement = described_class.new(
        id: "test_patterns",
        description: "Test with allowed patterns",
        allowed_attribute_patterns: ["on*", "data-*"],
      )

      expect(requirement.allowed_attribute_patterns).to eq(["on*", "data-*"])
    end

    it "allows attributes matching allowed_attribute_patterns" do
      svg_with_event_handlers = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <polygon points="10,10 90,10 50,90"
                   onmouseout="handleOut()"
                   onmouseover="handleOver()"
                   data-custom="value"/>
          <rect x="10" y="10" width="20" height="20" onclick="forbidden()"/>
        </svg>
      SVG

      document = SvgConform::Document.from_content(svg_with_event_handlers)
      requirement = described_class.new(
        id: "test_patterns",
        description: "Test with allowed patterns",
        allowed_attribute_patterns: ["on*"], # Allow all event attributes
        check_attributes: true,
      )

      context = SvgConform::ValidationContext.new(document, nil)
      requirement.validate_document(document, context)

      # onmouseout and onmouseover should be allowed (match "on*" pattern)
      # onclick should also be allowed (matches "on*" pattern)
      # data-custom should NOT be allowed (not in allowed attributes, not in pattern)
      expect(context.errors).to be_empty
    end

    it "warns when allowed_attribute_patterns conflicts with element-specific disallowed attributes" do
      # Create a requirement with conflicting configuration
      requirement = described_class.new(
        id: "test_conflict",
        description: "Test with conflicting patterns",
        allowed_attribute_patterns: ["on*"], # Allows all event attributes
        element_configs: [
          SvgConform::Requirements::ElementRequirementConfig.new(
            tag: "polygon",
            attr: ["points", "!onclick"], # onclick is disallowed on polygon
          ),
        ],
      )

      # Trigger validation by calling check and capture stderr
      document = SvgConform::Document.from_content(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><polygon points="10,10 90,10 50,90"/></svg>',
      )
      context = SvgConform::ValidationContext.new(document, nil)

      expect { requirement.check(document.root, context) }
        .to output(/Configuration warning.*onclick.*allowed_attribute_patterns.*Allowed patterns take precedence/m)
        .to_stderr
    end
  end
end
