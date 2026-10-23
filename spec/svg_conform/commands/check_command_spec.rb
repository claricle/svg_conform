# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe SvgConform::Commands::Check do
  let(:valid_svg) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
        <rect x="10" y="10" width="50" height="50" fill="red"/>
      </svg>
    SVG
  end

  let(:invalid_svg) do
    <<~SVG
      <svg width="100" height="100">
        <rect x="10" y="10" width="50" height="50" fill="red"/>
      </svg>
    SVG
  end

  describe "#execute" do
    it "validates a file and returns status" do
      tempfile = Tempfile.new(["test", ".svg"])
      tempfile.write(valid_svg)
      tempfile.close

      options = { profile: "svg_1_2_rfc", format: "table" }
      command = described_class.new(tempfile.path, options)

      expect { command.execute }.to output(/profile svg_1_2_rfc\nVALID|profile svg_1_2_rfc\nINVALID/).to_stdout
        .and raise_error(SystemExit)

      tempfile.unlink
    end

    it "reports errors for invalid files" do
      tempfile = Tempfile.new(["test", ".svg"])
      tempfile.write(invalid_svg)
      tempfile.close

      options = { profile: "svg_1_2_rfc", format: "table" }
      command = described_class.new(tempfile.path, options)

      expect { command.execute }.to output(/INVALID: .*\n\nerror  /).to_stdout
        .and raise_error(SystemExit)

      tempfile.unlink
    end

    it "supports YAML output format" do
      tempfile = Tempfile.new(["test", ".svg"])
      tempfile.write(valid_svg)
      tempfile.close

      options = { profile: "svg_1_2_rfc", format: "yaml" }
      command = described_class.new(tempfile.path, options)

      expect { command.execute }.to output(/---/).to_stdout
        .and raise_error(SystemExit)

      tempfile.unlink
    end

    it "supports JSON output format" do
      tempfile = Tempfile.new(["test", ".svg"])
      tempfile.write(valid_svg)
      tempfile.close

      options = { profile: "svg_1_2_rfc", format: "json" }
      command = described_class.new(tempfile.path, options)

      expect { command.execute }.to output(/\{/).to_stdout
        .and raise_error(SystemExit)

      tempfile.unlink
    end

    it "renders JSON from the canonical report, keeping the info diagnostic" do
      fixture = File.expand_path("../../fixtures/diagnostics/external-reference-info.svg",
                                 __dir__)
      options = { profile: "svg_1_2_rfc", format: "json" }
      command = described_class.new(fixture, options)

      expect { command.execute }
        .to output(/"infos": 1.*"requirement_id": "link_validation".*"severity": "info"|"severity": "info".*"requirement_id": "link_validation"/m)
        .to_stdout.and raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
    end

    it "renders the info diagnostic in the human (table) format" do
      fixture = File.expand_path("../../fixtures/diagnostics/external-reference-info.svg",
                                 __dir__)
      command = described_class.new(fixture, { profile: "svg_1_2_rfc", format: "table" })

      expect { command.execute }.to output(/info  link_validation/).to_stdout
        .and raise_error(SystemExit)
    end

    it "handles missing files gracefully" do
      options = { profile: "svg_1_2_rfc", format: "table" }
      command = described_class.new("nonexistent.svg", options)

      expect do
        command.execute
      end.to raise_error(SvgConform::Commands::Check::FileNotFoundError,
                         /nonexistent.svg/)
    end
  end
end
