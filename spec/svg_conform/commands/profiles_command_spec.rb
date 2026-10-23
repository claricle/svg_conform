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

    it "lists the SVG 1.1 Full static profile (name is truncated by the table)" do
      command = described_class.new({})

      expect { command.execute }.to output(/svg_1_1_full_.*SVG 1.1 Full/m).to_stdout
    end

    it "shows the svg_1_1_full_static requirements in verbose mode" do
      command = described_class.new({ verbose: true })

      expect { command.execute }
        .to output(/Profile: svg_1_1_full_static.*Svg11DocumentRequirement/m).to_stdout
    end

    it "lists the opt-in svg_2_secure_static profile" do
      expect { described_class.new({}).execute }
        .to output(/svg_2_secure/).to_stdout
    end
  end
end
