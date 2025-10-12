# -*- encoding: utf-8 -*-
# stub: compare-xml 0.66 ruby lib

Gem::Specification.new do |s|
  s.name = "compare-xml".freeze
  s.version = "0.66".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vadim Kononov".freeze]
  s.bindir = "exe".freeze
  s.date = "2018-04-24"
  s.description = "CompareXML is a fast, lightweight and feature-rich tool that will solve your XML/HTML comparison or diffing needs. its purpose is to compare two instances of Nokogiri::XML::Node or Nokogiri::XML::NodeSet for equality or equivalency.".freeze
  s.email = ["vadim@poetic.com".freeze]
  s.homepage = "https://github.com/vkononov/compare-xml".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.5.9".freeze
  s.summary = "A customizable tool that compares two instances of Nokogiri::XML::Node for equality or equivalency.".freeze

  s.installed_by_version = "3.5.9".freeze if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<nokogiri>.freeze, ["~> 1.8".freeze])
end
