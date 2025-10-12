# frozen_string_literal: true

require "spec_helper"

RSpec.describe SvgConform::Commands::SvgcheckGenerate do
  describe "#execute" do
    it "initializes with svgcheck_repo_path and options" do
      svgcheck_repo_path = "svgcheck-reference"
      options = { single_file: "test.svg" }
      command = described_class.new(svgcheck_repo_path, options)
      expect(command).to be_a(described_class)
    end
  end
end
