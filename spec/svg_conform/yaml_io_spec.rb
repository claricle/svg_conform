# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe SvgConform::YamlIO do
  def with_yaml(text)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "t.yml")
      File.write(path, text)
      yield path
    end
  end

  let(:aliased) { "a: &x {k: 1}\nb: *x\nc: :sym\n" }

  it "loads aliases and permitted Symbols like Psych" do
    with_yaml(aliased) do |path|
      expect(described_class.safe_load_file(
               path, permitted_classes: [Symbol], aliases: true
             )).to eq("a" => { "k" => 1 }, "b" => { "k" => 1 }, "c" => :sym)
    end
  end

  it "rejects aliases unless aliases: true" do
    with_yaml(aliased) do |path|
      expect do
        described_class.safe_load_file(path, permitted_classes: [Symbol])
      end.to raise_error(Yeptris::Psych::AliasesError)
    end
  end

  it "loads the bundled quality config through Configuration" do
    expect(SvgConform::QualityMetrics::Configuration.default).not_to be_nil
  end

  it "dumps byte-identical to Psych for a manifest-like hash" do
    h = { "a" => :b, "c" => [1, "x: y", nil], "d" => { "e" => 1.5 } }
    expect(described_class.dump(h)).to eq(Psych.dump(h))
  end
end
