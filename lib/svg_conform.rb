# frozen_string_literal: true

require "lutaml/model"

# Configure Lutaml::Model adapters
Lutaml::Model::Config.configure do |config|
  config.xml_adapter_type = :nokogiri
  config.json_adapter_type = :standard_json
  config.yaml_adapter_type = :standard_yaml
end

require_relative "svg_conform/version"
require_relative "svg_conform/document"
require_relative "svg_conform/sax_document"
require_relative "svg_conform/validation_context"
require_relative "svg_conform/validation_result"
require_relative "svg_conform/profiles"
require_relative "svg_conform/requirements"
require_relative "svg_conform/remediations"
require_relative "svg_conform/remediation_result"
require_relative "svg_conform/external_checkers"
require_relative "svg_conform/cli"

module SvgConform
  class Error < StandardError; end
  class ParseError < Error; end
  class ValidationError < Error; end
  class ProfileError < Error; end
  class RuleError < Error; end

  # Autoload core classes
  autoload :Validator, File.expand_path("svg_conform/validator", __dir__)
  autoload :Fixer, "svg_conform/fixer"
  autoload :RemediationEngine, "svg_conform/remediation_engine"
  autoload :ConformanceReport,
           File.expand_path("svg_conform/conformance_report", __dir__)
  autoload :BatchReport,
           File.expand_path("svg_conform/batch_report", __dir__)
  autoload :ReportComparator,
           File.expand_path("svg_conform/report_comparator", __dir__)
  autoload :NamespaceRemediation, "svg_conform/namespace_remediation"
  autoload :Cli, "svg_conform/cli"

  # Autoload command classes
  module Commands
    autoload :Check, "svg_conform/commands/check"
    autoload :Compare, "svg_conform/commands/compare"
    autoload :Compatibility,
             File.expand_path("svg_conform/commands/compatibility", __dir__)
    autoload :GenerateReports,
             File.expand_path("svg_conform/commands/generate_reports", __dir__)
    autoload :Profiles, "svg_conform/commands/profiles"
  end

  # Convenience method to create a new validator
  def self.validator
    Validator.new
  end

  # Validate a file with the specified profile
  def self.validate_file(file_path, profile: :svg_1_2_rfc, **options)
    validator.validate_file(file_path, profile: profile, **options)
  end

  # Validate SVG content with the specified profile
  def self.validate(svg_content, profile: :svg_1_2_rfc, **options)
    validator.validate(svg_content, profile: profile, **options)
  end
end
