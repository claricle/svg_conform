# -*- encoding: utf-8 -*-
# stub: table_tennis 0.0.7 ruby lib

Gem::Specification.new do |s|
  s.name = "table_tennis".freeze
  s.version = "0.0.7".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "homepage_uri" => "https://github.com/gurgeous/table_tennis", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/gurgeous/table_tennis" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Adam Doppelt".freeze]
  s.date = "2025-08-06"
  s.email = "amd@gurge.com".freeze
  s.homepage = "https://github.com/gurgeous/table_tennis".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.0.0".freeze)
  s.rubygems_version = "3.5.9".freeze
  s.summary = "Stylish tables in your terminal.".freeze

  s.installed_by_version = "3.5.9".freeze if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<csv>.freeze, ["~> 3.3".freeze])
  s.add_runtime_dependency(%q<ffi>.freeze, ["~> 1.17".freeze])
  s.add_runtime_dependency(%q<memo_wise>.freeze, ["~> 1.11".freeze])
  s.add_runtime_dependency(%q<paint>.freeze, ["~> 2.3".freeze])
  s.add_runtime_dependency(%q<unicode-display_width>.freeze, ["~> 3.1".freeze])
end
