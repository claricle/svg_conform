# frozen_string_literal: true

require "spec_helper"

RSpec.describe SvgConform::BatchReport do
  describe "initialization" do
    it "creates a batch report with default values" do
      report = described_class.new
      expect(report.files).to eq([])
      expect(report.manifest).to eq({})
      expect(report.timestamp).not_to be_nil
    end
  end

  describe "calculate_statistics" do
    it "calculates statistics correctly" do
      report = described_class.new
      report.profile = "metanorma"

      # Add some file results
      3.times do |i|
        file_result = SvgConform::FileResult.new
        file_result.filename = "file#{i}.svg"
        file_result.valid_before = false
        file_result.valid_after = i < 2 # 2 out of 3 valid after
        file_result.status = i < 2 ? "remediated" : "failed"
        report.files << file_result
      end

      report.calculate_statistics

      expect(report.total_files).to eq(3)
      expect(report.valid_before).to eq(0)
      expect(report.valid_after).to eq(2)
      expect(report.remediated).to eq(2)
      expect(report.failed).to eq(1)
      expect(report.success_rate).to eq(66.7)
    end
  end

  describe "serialization" do
    it "serializes to JSON" do
      report = described_class.new
      report.profile = "metanorma"
      report.total_files = 10

      json = report.to_json
      expect(json).to be_a(String)
      expect(json).to include('"profile":"metanorma"')
      expect(json).to include('"total_files":10')
    end

    it "serializes to YAML" do
      report = described_class.new
      report.profile = "metanorma"
      report.total_files = 10

      yaml = report.to_yaml
      expect(yaml).to be_a(String)
      expect(yaml).to include("profile: metanorma")
      expect(yaml).to include("total_files: 10")
    end
  end
end

RSpec.describe SvgConform::FileResult do
  describe "initialization" do
    it "creates a file result" do
      result = described_class.new
      result.filename = "test.svg"
      result.status = "valid"

      expect(result.filename).to eq("test.svg")
      expect(result.status).to eq("valid")
    end
  end

  describe "serialization" do
    it "serializes to JSON" do
      result = described_class.new
      result.filename = "test.svg"
      result.status = "remediated"

      json = result.to_json
      expect(json).to include('"filename":"test.svg"')
      expect(json).to include('"status":"remediated"')
    end

    it "serializes to YAML" do
      result = described_class.new
      result.filename = "test.svg"
      result.status = "remediated"

      yaml = result.to_yaml
      expect(yaml).to include("filename: test.svg")
      expect(yaml).to include("status: remediated")
    end
  end
end
