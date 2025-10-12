# -*- encoding: utf-8 -*-
# stub: paint 2.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "paint".freeze
  s.version = "2.3.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jan Lelis".freeze]
  s.date = "2022-07-05"
  s.description = "Terminal painter with RGB and 256 (fallback) color and terminal effects support. No string extensions! Usage: Paint['string', :red, :bright]".freeze
  s.email = ["hi@ruby.consulting".freeze]
  s.extra_rdoc_files = ["README.md".freeze, "CHANGELOG.md".freeze, "MIT-LICENSE.txt".freeze]
  s.files = ["CHANGELOG.md".freeze, "MIT-LICENSE.txt".freeze, "README.md".freeze]
  s.homepage = "https://github.com/janlelis/paint".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3".freeze)
  s.rubygems_version = "3.5.9".freeze
  s.summary = "Terminal painter!".freeze

  s.installed_by_version = "3.5.9".freeze if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.11".freeze])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0".freeze])
  s.add_development_dependency(%q<benchmark-ips>.freeze, ["~> 2.10".freeze])
end
