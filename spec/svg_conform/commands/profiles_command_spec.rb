# frozen_string_literal: true

require "spec_helper"

RSpec.describe SvgConform::Commands::Profiles do
  describe "#execute" do
    it "initializes with options" do
      options = {}
      command = described_class.new(options)
      expect(command).to be_a(described_class)
    end

    it "lists available profiles" do
      options = {}
      command = described_class.new(options)

      expect { command.execute }.to output(/Available SVG Profiles/).to_stdout
    end

    it "lists the opt-in svg_2_secure_static profile" do
      expect { described_class.new({}).execute }
        .to output(/svg_2_secure/).to_stdout
    end
  end
end
