# frozen_string_literal: true

require "spec_helper"
require "svg_conform/quality_metrics/configuration"
require "psych"
require "tempfile"

RSpec.describe SvgConform::QualityMetrics::Configuration do
  describe ".default" do
    let(:hash) { described_class.default.instance_variable_get(:@hash) }

    it "loads bundled violation types as Symbols" do
      types = hash.fetch("severity_levels").values.flat_map do |level|
        level.fetch("violation_types")
      end

      expect(types).to include(:reference_violation)
      expect(types).to all(be_a(Symbol))
    end

    it "preserves the entire Psych-loaded configuration" do
      expected = Psych.safe_load_file(described_class::DEFAULT_CONFIG_PATH,
                                      permitted_classes: [Symbol],
                                      permitted_symbols: [], aliases: true)

      expect(hash).to eq(expected)
    end
  end

  describe ".from_yaml" do
    def load_yaml(source)
      Tempfile.create(["quality_metrics", ".yml"]) do |file|
        file.write(source)
        file.flush
        described_class.from_yaml(file.path)
      end
    end

    it "preserves quoted Symbol values" do
      pending "yeptris differs from Psych: quoted Symbols retain quotes; upstream issue to be filed, see PR description"

      config = load_yaml('a: :"x y"')

      expect(config.instance_variable_get(:@hash)).to eq("a" => :"x y")
    end

    it "rejects disallowed dates with the yeptris error naming Date" do
      expect { load_yaml("f: 2024-01-02\n") }
        .to raise_error(Yeptris::Psych::DisallowedClass, /Date/)
    end

    it "rejects disallowed times with the yeptris error naming Time" do
      pending "yeptris differs from Psych: disallowed Time is reported as Date; upstream issue to be filed, see PR description"

      expect { load_yaml("f: 2024-01-02 10:00:00\n") }
        .to raise_error(Yeptris::Psych::DisallowedClass, /Time/)
    end

    it "rejects invalid YAML with the yeptris syntax error" do
      expect { load_yaml("a: [\n") }.to raise_error(Yeptris::Psych::SyntaxError)
    end

    it "resolves anchors and aliases" do
      path = File.expand_path("../../fixtures/quality_metrics/aliases.yml", __dir__)
      hash = described_class.from_yaml(path).instance_variable_get(:@hash)

      expect(hash.fetch("remediable_types")).to eq([:reference_violation])
      expect(hash.dig("severity_levels", "critical", "violation_types"))
        .to eq(hash.fetch("remediable_types"))
    end

    it "rejects a non-permitted class with the yeptris error" do
      Tempfile.create(["quality_metrics", ".yml"]) do |file|
        file.write("--- !ruby/object:Object {}\n")
        file.flush

        expect { described_class.from_yaml(file.path) }
          .to raise_error(Yeptris::Psych::DisallowedClass)
      end
    end
  end
end
