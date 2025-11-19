# frozen_string_literal: true

require "lutaml/model"
require_relative "requirements"
require_relative "remediations"

module SvgConform
  # Base class for SVG validation profiles using lutaml-model serialization
  class Profile < Lutaml::Model::Serializable
    attribute :name, :string
    attribute :description, :string
    attribute :import, :string
    attribute :requirements, SvgConform::Requirements::BaseRequirement,
              collection: true, polymorphic: true
    attribute :remediations, SvgConform::Remediations::BaseRemediation,
              collection: true, polymorphic: true

    def self.build_class_map(dir_name, namespace, excluded_file)
      target_dir = File.expand_path(dir_name, __dir__)
      class_map = {}

      Dir.glob(File.join(target_dir,
                         "*_#{dir_name.chomp('s')}.rb")).each do |file|
        filename = File.basename(file, ".rb")
        next if filename == excluded_file

        class_name = filename.split("_").map(&:capitalize).join
        class_map[class_name] = "SvgConform::#{namespace}::#{class_name}"
      end

      class_map
    end

    # Build class maps dynamically from filesystem
    REQUIREMENTS_CLASS_MAP = build_class_map(
      "requirements", "Requirements", "base_requirement"
    )
    REMEDIATIONS_CLASS_MAP = build_class_map(
      "remediations", "Remediations", "base_remediation"
    )

    yaml do
      map "name", to: :name
      map "description", to: :description
      map "import", to: :import
      map "requirements", to: :requirements, polymorphic: {
        attribute: "type",
        class_map: REQUIREMENTS_CLASS_MAP,
      }
      map "remediations", to: :remediations, polymorphic: {
        attribute: "type",
        class_map: REMEDIATIONS_CLASS_MAP,
      }
    end

    # New requirement methods
    def add_requirement(requirement)
      self.requirements ||= []
      requirements << requirement
      self
    end

    def remove_requirement(requirement_id)
      return self unless requirements

      requirements.reject! { |req| req.id == requirement_id }
      self
    end

    def has_requirement?(requirement_id)
      return false unless requirements

      requirements.any? { |req| req.id == requirement_id }
    end

    def get_requirement(requirement_id)
      return nil unless requirements

      requirements.find { |req| req.id == requirement_id }
    end

    def requirement_count
      requirements&.size || 0
    end

    # New remediation methods
    def add_remediation(remediation)
      self.remediations ||= []
      remediations << remediation
      self
    end

    def remove_remediation(remediation_id)
      return self unless remediations

      remediations.reject! { |rem| rem.id == remediation_id }
      self
    end

    def has_remediation?(remediation_id)
      return false unless remediations

      remediations.any? { |rem| rem.id == remediation_id }
    end

    def get_remediation(remediation_id)
      return nil unless remediations

      remediations.find { |rem| rem.id == remediation_id }
    end

    def remediation_count
      remediations&.size || 0
    end

    def validate(document)
      # Use SAX mode for validation performance
      # Convert document to content string if it's a DOM document
      if document.is_a?(Document)
        content = document.to_xml
        sax_doc = SaxDocument.from_content(content)
        sax_doc.validate_with_profile(self)
      elsif document.respond_to?(:to_xml)
        # Handle any document-like object
        content = document.to_xml
        sax_doc = SaxDocument.from_content(content)
        sax_doc.validate_with_profile(self)
      else
        # Fallback to DOM mode for backward compatibility
        context = ValidationContext.new(document, self)

        # Validate using requirements system
        requirements&.each do |requirement|
          requirement.validate_document(document, context)
        end

        ValidationResult.new(document, self, context)
      end
    end

    def validate_file(file_path)
      # Use SAX mode directly
      sax_doc = SaxDocument.from_file(file_path)
      sax_doc.validate_with_profile(self)
    end

    # Apply remediations to a document after validation
    def apply_remediations(document)
      # Run validation to get failed requirements
      validation_result = validate(document)

      all_changes = []

      # Apply remediations for failed requirements
      remediations&.each do |remediation|
        if remediation.should_execute?(validation_result.failed_requirements)
          changes = remediation.apply(document, nil)
          all_changes.concat(changes) if changes
        end
      end

      all_changes
    end

    # Simple YAML loading methods for individual profiles
    def self.load_from_file(file_path)
      yaml_content = File.read(file_path)
      from_yaml(yaml_content)
    end

    def self.save_to_file(profile, file_path)
      File.write(file_path, profile.to_yaml)
    end

    def to_s
      "#{name}: #{description} (#{requirement_count} checks, #{remediation_count} remediations)"
    end
  end
end
