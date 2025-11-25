# frozen_string_literal: true

require_relative "lib/svg_conform/version"

all_files_in_git = Dir.chdir(File.expand_path(__dir__)) do
  `git ls-files -z`.split("\x0")
end

Gem::Specification.new do |spec|
  spec.name = "svg_conform"
  spec.version = SvgConform::VERSION
  spec.authors = ["Ribose"]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "SVG profile conformance checker for Ruby."
  spec.homepage = "https://github.com/claricle/svg_conform"
  spec.license = "BSD-2-Clause"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.1.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"

  spec.files = all_files_in_git
    .reject { |f| f.match(%r{\A(?:test|features|bin|\.)/}) }

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "lutaml-model", "~> 0.7"
  spec.add_dependency "moxml", "~> 0.1", ">= 0.1.9"
  spec.add_dependency "table_tennis"
  spec.add_dependency "thor"
end
