# frozen_string_literal: true

require "spec_helper"

RSpec.describe "svg_conform.gemspec" do # rubocop:disable RSpec/DescribeClass
  let(:specification) { Gem::Specification.load("svg_conform.gemspec") }

  it "declares every library the gem requires at load time as a runtime dependency" do
    expect(File.read("lib/svg_conform.rb")).to include('require "lens_core"')
    expect(specification.runtime_dependencies.map(&:name)).to include("lens_core")
  end

  it "constrains lens_core to the released 0.x line" do
    dependency = specification.runtime_dependencies.find { |d| d.name == "lens_core" }

    expect(dependency.requirement.to_s).to eq("~> 0.1")
  end
end
