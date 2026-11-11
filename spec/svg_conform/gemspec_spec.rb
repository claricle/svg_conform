# frozen_string_literal: true

require "spec_helper"

RSpec.describe "svg_conform.gemspec" do # rubocop:disable RSpec/DescribeClass
  let(:specification) { Gem::Specification.load("svg_conform.gemspec") }

  it "declares the published lens_core gem as a runtime dependency" do
    # lens_core 0.1.0 is on rubygems, so the 0.2.5-era optionality is
    # obsolete: leaving it undeclared crashed the CLI on strict bundler
    # deployments (rescue LoadError misses Bundler::GemNotFound,
    # claricle/svg_conform#130). The guard in svg_conform.rb stays as a
    # version-compatibility courtesy, not as the dependency mechanism.
    dependency = specification.runtime_dependencies.find { |d| d.name == "lens_core" }

    expect(dependency).not_to be_nil
    expect(dependency.requirement).to eq(Gem::Requirement.new("~> 0.1"))
  end

  it "declares yeptris as a runtime dependency" do
    dependency = specification.runtime_dependencies.find { |d| d.name == "yeptris" }

    expect(dependency).not_to be_nil
    expect(dependency.requirement).to eq(Gem::Requirement.new("~> 0.6.36"))
  end

  it "loads the Psych-compatible yeptris API" do
    require "yeptris/psych"

    expect(defined?(Yeptris::Psych)).to be_truthy
  end

  it "exposes the lens_core availability probe" do
    expect(SvgConform).to respond_to(:lens_core_available?)
    expect(SvgConform.lens_core_available?).to be_truthy.or be_falsey
  end

  it "keeps the committed lockfile in sync with the gem version" do
    # The release flow (metanorma/ci rubygems-release) deletes the lock and
    # bumps version.rb without restoring it: staleness is this repo's own
    # guard (ci's words). Without this check, every post-release PR fails
    # bundler 4's frozen install ("gemspecs for path gems changed") before
    # anyone sees why.
    lock = File.read("Gemfile.lock")
    path_version = lock[/\APATH\n  remote: \.\n  specs:\n    svg_conform \(([^)]+)\)/, 1]
    expect(path_version).to eq(SvgConform::VERSION)
  end
end
