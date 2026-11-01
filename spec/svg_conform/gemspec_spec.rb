# frozen_string_literal: true

require "spec_helper"

RSpec.describe "svg_conform.gemspec" do # rubocop:disable RSpec/DescribeClass
  let(:specification) { Gem::Specification.load("svg_conform.gemspec") }

  it "does not gate installation on the unpublished lens_core gem" do
    # lens_core is optional: the canonical diagnostics renderer rides it
    # when installed, and the plain structural serializers answer when
    # not. A runtime dependency on the unpublished gem made 0.2.5
    # uninstallable for every consumer.
    expect(specification.runtime_dependencies.map(&:name)).not_to include("lens_core")
    expect(File.read("lib/svg_conform.rb")).to include("rescue LoadError")
  end

  it "exposes the lens_core availability probe" do
    expect(SvgConform).to respond_to(:lens_core_available?)
    expect(SvgConform.lens_core_available?).to be_truthy.or be_falsey
  end
end
