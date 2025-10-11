# frozen_string_literal: true

require "spec_helper"

RSpec.describe SvgConform::Commands::Compare do
  describe "#execute" do
    it "initializes with file and options" do
      options = { profile: "svg_1_2_rfc" }
      command = described_class.new("test.svg", options)
      expect(command).to be_a(described_class)
    end
  end
end
