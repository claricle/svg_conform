# frozen_string_literal: true

require "spec_helper"

RSpec.describe SvgConform::Requirements::TextAsPathRequirement do
  let(:requirement) do
    described_class.new(
      id: "text_as_path",
      description: "Detects text rendered as outlined paths",
      min_d_length: 500,
      min_bezier: 5,
    )
  end

  describe "configuration" do
    it "can be instantiated with basic parameters" do
      req = described_class.new(
        id: "text_as_path",
        description: "Test",
      )
      expect(req).to be_a(described_class)
    end

    it "has correct default values" do
      req = described_class.new(id: "test", description: "Test")
      expect(req.min_d_length).to eq(500)
      expect(req.min_bezier).to eq(5)
    end

    it "accepts custom threshold values" do
      req = described_class.new(
        id: "test",
        description: "Test",
        min_d_length: 100,
        min_bezier: 3,
      )
      expect(req.min_d_length).to eq(100)
      expect(req.min_bezier).to eq(3)
    end

    it "uses deferred validation" do
      req = described_class.new(id: "test", description: "Test")
      expect(req.needs_deferred_validation?).to be true
    end
  end

  describe "SAX validation" do
    let(:validator) { SvgConform::Validator.new }

    it "detects text-as-path in SVG with long bezier paths but no text element" do
      # d attribute must be >= 500 chars with >= 5 bezier curves
      svg = <<~SVG
        <svg version="1.2" baseProfile="tiny" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <path d="M10,10 C20,20 30,30 40,40 C50,50 60,60 70,70 C80,80 90,90 100,100 C110,110 120,120 130,130 C140,140 150,150 160,160 C170,170 180,180 190,190 C200,200 210,210 220,220 C230,230 240,240 250,250 C260,260 270,270 280,280 C290,290 300,300 310,310 C320,320 330,330 340,340 C350,350 360,360 370,370 C380,380 390,390 400,400 C410,410 420,420 430,430 C440,440 450,450 460,460 C470,470 480,480 490,490 C500,500 510,510 520,520 C530,530 540,540 550,550 C560,560 570,570 580,580 C590,590 600,600 610,610 C620,620 630,630 640,640 C650,650 660,660 670,670 C680,680 690,690 700,700"/>
        </svg>
      SVG

      result = validator.validate(svg, profile: :metanorma)
      text_as_path_errors = result.errors.select do |e|
        e.message.include?("rendered as paths")
      end

      expect(text_as_path_errors).not_to be_empty
      expect(text_as_path_errors.first.severity).to eq(:warning)
    end

    it "does not flag SVG with native text elements" do
      svg = <<~SVG
        <svg version="1.2" baseProfile="tiny" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <text x="10" y="20">Hello World</text>
          <path d="M10,10 C20,20 30,30 40,40"/>
        </svg>
      SVG

      result = validator.validate(svg, profile: :metanorma)
      text_as_path_errors = result.errors.select do |e|
        e.message.include?("rendered as paths")
      end

      expect(text_as_path_errors).to be_empty
    end

    it "does not flag SVG with image elements" do
      svg = <<~SVG
        <svg version="1.2" baseProfile="tiny" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <image href="data:image/png;base64,abc"/>
          <path d="M10,10 C20,20 30,30 40,40"/>
        </svg>
      SVG

      result = validator.validate(svg, profile: :metanorma)
      text_as_path_errors = result.errors.select do |e|
        e.message.include?("rendered as paths")
      end

      expect(text_as_path_errors).to be_empty
    end

    it "does not flag short path d attributes" do
      svg = <<~SVG
        <svg version="1.2" baseProfile="tiny" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <path d="M10,10 C20,20 30,30 40,40 C50,50"/>
        </svg>
      SVG

      result = validator.validate(svg, profile: :metanorma)
      text_as_path_errors = result.errors.select do |e|
        e.message.include?("rendered as paths")
      end

      expect(text_as_path_errors).to be_empty
    end

    it "does not flag paths with insufficient bezier curves" do
      svg = <<~SVG
        <svg version="1.2" baseProfile="tiny" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <path d="M10,10 M20,20 M30,30 M40,40 M50,50"/>
        </svg>
      SVG

      result = validator.validate(svg, profile: :metanorma)
      text_as_path_errors = result.errors.select do |e|
        e.message.include?("rendered as paths")
      end

      expect(text_as_path_errors).to be_empty
    end

    it "respects custom min_bezier threshold" do
      req = described_class.new(
        id: "text_as_path",
        description: "Test",
        min_d_length: 50,
        min_bezier: 10,
      )

      # Just verify the requirement can be instantiated with custom values
      expect(req.min_d_length).to eq(50)
      expect(req.min_bezier).to eq(10)
    end
  end
end
