# -*- encoding: utf-8 -*-
# stub: lutaml-model 0.7.7 ruby lib

Gem::Specification.new do |s|
  s.name = "lutaml-model".freeze
  s.version = "0.7.7".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Ribose Inc.".freeze]
  s.bindir = "exe".freeze
  s.date = "2025-07-31"
  s.description = "LutaML creating data models in Ruby\n".freeze
  s.email = ["open.source@ribose.com".freeze]
  s.executables = ["lutaml-model".freeze]
  s.files = ["exe/lutaml-model".freeze]
  s.homepage = "https://github.com/lutaml/lutaml-model".freeze
  s.licenses = ["BSD-2-Clause".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.0.0".freeze)
  s.rubygems_version = "3.5.9".freeze
  s.summary = "LutaML creating data models in Ruby".freeze

  s.installed_by_version = "3.5.9".freeze if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<moxml>.freeze, [">= 0.1.2".freeze])
  s.add_runtime_dependency(%q<thor>.freeze, [">= 0".freeze])
end
