# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SvgConform" do
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
