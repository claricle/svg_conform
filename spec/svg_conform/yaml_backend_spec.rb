# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SvgConform" do
  it "uses yeptris for lutaml-model YAML serialization" do
    expect(Lutaml::Model::Config.yaml_adapter_type).to eq(:yeptris)
  end

  Dir.glob(File.join(SvgConform::Profile::PROFILES_DIR, "*.yml")).each do |path|
    it "loads the bundled #{File.basename(path)} profile through yeptris" do
      expect(Lutaml::Yaml::Adapter::YeptrisAdapter).to receive(:parse).and_call_original

      profile = SvgConform::Profile.load_from_file(path)
      expected = Psych.safe_load_file(path)

      expect(profile.name).to eq(expected.fetch("name"))
      expect(profile.requirements.map(&:id))
        .to eq(expected.fetch("requirements", []).map { |requirement| requirement.fetch("id") })
      expect(Array(profile.remediations).map(&:id))
        .to eq(expected.fetch("remediations", []).map { |remediation| remediation.fetch("id") })
    end
  end

  it "loads conformance reports through yeptris" do
    expect(Lutaml::Yaml::Adapter::YeptrisAdapter).to receive(:parse).and_call_original

    report = SvgConform::ConformanceReport.from_yaml(<<~YAML)
      filename: example.svg
      valid: false
      errors:
        total_count: 1
        by_requirement:
          viewbox_required: 1
        issues:
          - requirement_id: viewbox_required
            message: Missing viewBox
            line: 2
    YAML

    expect(report.filename).to eq("example.svg")
    expect(report.valid).to be(false)
    expect(report.errors.total_count).to eq(1)
    expect(report.errors.by_requirement).to eq("viewbox_required" => 1)
    expect(report.errors.issues.first.message).to eq("Missing viewBox")
    expect(report.errors.issues.first.line).to eq(2)
  end

  it "keeps lib free of yaml requires and bare YAML or Psych calls" do
    lib_dir = File.expand_path("../../lib", __dir__)
    forbidden = /\brequire\s*(?:\(\s*)?["']yaml["']|(?<![\w:])(?:::)?(?:YAML|Psych)\s*\./
    violations = Dir.glob("#{lib_dir}/**/*").select { |path| File.file?(path) }
      .flat_map do |path|
        File.readlines(path).each_with_index.filter_map do |line, index|
          next unless line.match?(forbidden)

          "#{path.delete_prefix("#{lib_dir}/")}:#{index + 1}: #{line.strip}"
        end
      end

    expect(violations).to be_empty,
                          "Use SvgConform::YamlIO or Yeptris::Psych in lib/:\n#{violations.join("\n")}"
  end
end
