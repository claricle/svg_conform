# frozen_string_literal: true

require "spec_helper"
require "psych"
require "tempfile"

RSpec.describe SvgConform::ExternalCheckers::Svgcheck::Parser do
  describe "mapping config loading" do
    let(:yaml) do
      <<~YAML
        message_patterns:
          - pattern: "Element (\\\\w+) is not allowed"
            requirement: forbidden_content
        requirement_mappings:
          forbidden_content:
            - script
        skip_patterns:
          - "^Warning:"
        special_rules: {}
      YAML
    end

    let(:file) { Tempfile.new(["svgcheck_mapping", ".yml"]) }
    let(:path) { file.path }

    before do
      file.write(yaml)
      file.flush
    end

    after { file.close! }

    it "loads message_patterns, requirement_mappings and skip_patterns" do
      config = described_class.new(path).mapping_config

      expect(config["message_patterns"]).to be_an(Array)
      expect(config["requirement_mappings"]).to eq("forbidden_content" => ["script"])
      expect(config["skip_patterns"]).to eq(["^Warning:"])
    end

    it "loads the same hash as Psych" do
      expect(described_class.new(path).mapping_config).to eq(Psych.load_file(path))
    end

    it "loads the bundled mapping config the same as Psych" do
      path = File.expand_path("../../../../config/svgcheck_mapping.yml", __dir__)
      skip "no bundled mapping" unless File.exist?(path)

      expect(described_class.new(path).mapping_config).to eq(Psych.load_file(path))
    end
  end
end
