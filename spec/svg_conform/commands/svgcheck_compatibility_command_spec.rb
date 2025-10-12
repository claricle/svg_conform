# frozen_string_literal: true

require "spec_helper"

RSpec.describe SvgConform::Commands::SvgcheckCompatibility do
  describe "#execute" do
    it "initializes with options" do
      options = {}
      command = described_class.new(options)
      expect(command).to be_a(described_class)
    end
  end
end
