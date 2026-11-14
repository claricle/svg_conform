# frozen_string_literal: true

require "lutaml/model"
require "lutaml/yaml/adapter/yeptris_adapter"
require "yeptris/psych"

# lens_core is optional (0.2.5 shipped it as a hard dependency while the
# gem is still unpublished, which made every fresh resolve unsolvable).
# When present it renders the canonical diagnostics reports; when absent
# the plain structural serializers answer instead.
begin
  require "lens_core"
rescue LoadError
  nil
end

# Configure Lutaml::Model adapters
Lutaml::Model::Config.configure do |config|
  config.xml_adapter_type = :leptris
  config.json_adapter_type = :standard_json
  config.yaml_adapter_type = :yeptris
end

require_relative "svg_conform/version"
require_relative "svg_conform/constants"
require_relative "svg_conform/profile"
require_relative "svg_conform/profiles"
require_relative "svg_conform/document"
require_relative "svg_conform/sax_document"
require_relative "svg_conform/element_proxy"
require_relative "svg_conform/errors/validation_issue"
require_relative "svg_conform/errors/validation_notice"
require_relative "svg_conform/validation_context"
require_relative "svg_conform/validation_result"
require_relative "svg_conform/validator"
require_relative "svg_conform/conformance_report"
require_relative "svg_conform/batch_report"
require_relative "svg_conform/requirements"
require_relative "svg_conform/references"
require_relative "svg_conform/remediations"
require_relative "svg_conform/remediation_result"
require_relative "svg_conform/remediation_engine"
require_relative "svg_conform/remediation_runner"
require_relative "svg_conform/fixer"
require_relative "svg_conform/external_checkers"

module SvgConform
  # The native lutaml-model loader loses binary decoding and accepts Ruby
  # object tags. Keep its permitted classes, using yeptris's safe loader.
  module ModelYamlSafeLoad
    def parse(yaml, _options = {})
      Yeptris::Psych.safe_load(
        yaml, permitted_classes: Lutaml::Yaml::Adapter::StandardAdapter::PERMITTED_CLASSES
      )
    rescue Yeptris::Psych::SyntaxError => e
      # Preserve the adapter's Psych error boundary so lutaml-model wraps
      # malformed input in InvalidFormatError as it does for other formats.
      raise syntax_error(e)
    rescue Yeptris::Psych::AliasesError
      raise ::Psych::AliasesNotEnabled
    end
  end

  # Keep stored YAML byte-compatible until yeptris's emitter matches the
  # standard adapter for non-BMP text. Reads still use yeptris throughout.
  module ModelYamlStableDump
    def to_yaml(options = {})
      Lutaml::Yaml::Adapter::StandardAdapter.new(@attributes).to_yaml(options)
    end
  end

  Lutaml::Yaml::Adapter::YeptrisAdapter.singleton_class.prepend(ModelYamlSafeLoad)
  Lutaml::Yaml::Adapter::YeptrisAdapter.prepend(ModelYamlStableDump)

  class Error < StandardError; end
  class ParseError < Error; end
  class ValidationError < Error; end
  class ProfileError < Error; end
  class RuleError < Error; end

  # True when the optional lens_core diagnostics renderer is installed.
  def self.lens_core_available?
    return @lens_core_available unless @lens_core_available.nil?

    @lens_core_available = begin
      require "lens_core"
      true
    rescue LoadError
      false
    end
  end

  require_relative "svg_conform/diagnostics/lens_core_adapter"

  # Autoload core classes
  autoload :YamlIO, File.expand_path("svg_conform/yaml_io", __dir__)
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

  # Image quality analysis
  autoload :ImageQualityAnalyzer, "svg_conform/image_quality_analyzer"
  autoload :SvgQualityReport, "svg_conform/quality_report"
  autoload :SvgQualityBatchReport, "svg_conform/quality_report"

  # Quality metrics sub-system
  module QualityMetrics
    autoload :Configuration, "svg_conform/quality_metrics/configuration"
    autoload :ErrorAnalyzer, "svg_conform/quality_metrics/error_analyzer"
    autoload :FeatureDetector, "svg_conform/quality_metrics/feature_detector"
    autoload :ComplexityCalculator,
             "svg_conform/quality_metrics/complexity_calculator"
    autoload :QualityCalculator,
             "svg_conform/quality_metrics/quality_calculator"
    autoload :ErrorBreakdown, "svg_conform/quality_metrics/error_breakdown"
    autoload :FeatureFlags, "svg_conform/quality_metrics/feature_flags"
    autoload :QualityScore, "svg_conform/quality_metrics/quality_score"
    autoload :ComplexityMetrics, "svg_conform/quality_metrics/complexity_metrics"
    autoload :QualityResult, "svg_conform/quality_metrics/quality_result"
    autoload :QualityReportFormatter,
             "svg_conform/quality_metrics/quality_report_formatter"
  end
end
