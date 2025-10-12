# frozen_string_literal: true

require "spec_helper"

RSpec.describe SvgConform::Commands::SvgcheckGenerate do
  describe "#execute" do
    it "initializes with options" do
      options = { single_file: "test.svg" }
      command = described_class.new(options)
      expect(command).to be_a(SvgConform::Commands::SvgcheckGenerate)
    end
  end
end
