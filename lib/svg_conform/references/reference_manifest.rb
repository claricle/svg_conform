# frozen_string_literal: true

require "lutaml/model"
require_relative "id_definition"
require_relative "base_reference"

module SvgConform
  module References
    # Comprehensive manifest of all IDs and references in the document
    # Provides complete context for consumer validation decisions
    class ReferenceManifest < Lutaml::Model::Serializable
      attribute :source_document, :string
      attribute :available_ids, IdDefinition, collection: true, default: -> {
        []
      }
      attribute :internal_references, BaseReference, collection: true, default: -> {
        []
      }
      attribute :external_references, BaseReference, collection: true, default: -> {
        []
      }

      yaml do
        map "source_document", to: :source_document
        map "available_ids", to: :available_ids
        map "internal_references", to: :internal_references
        map "external_references", to: :external_references
      end

      json do
        map "source_document", to: :source_document
        map "available_ids", to: :available_ids
        map "internal_references", to: :internal_references
        map "external_references", to: :external_references
      end

      def initialize(source_document: nil)
        super()
        @source_document = source_document
        @available_ids = []
        @internal_references = []
        @external_references = []
      end

      # Register an ID definition
      def register_id(id_value, element_name:, line_number: nil,
column_number: nil)
        @available_ids << IdDefinition.new(
          id_value: id_value,
          element_name: element_name,
          line_number: line_number,
          column_number: column_number,
        )
      end

      # Register a reference
      def register_reference(reference)
        if reference.internally_validatable?
          @internal_references << reference
        elsif reference.requires_consumer_validation?
          @external_references << reference
        end
      end

      # Check if an ID is defined
      def id_defined?(id_value)
        @available_ids.any? { |id_def| id_def.id_value == id_value }
      end

      # Get references targeting a specific ID
      def references_to_id(id_value)
        @internal_references.select do |ref|
          ref.is_a?(InternalFragmentReference) &&
            ref.target_id == id_value
        end
      end

      # Get all references grouped by type
      def references_by_type
        all_refs = @internal_references + @external_references
        all_refs.group_by { |ref| ref.class.name.split("::").last }
      end

      # Get unresolved internal references (references to non-existent IDs)
      def unresolved_internal_references
        @internal_references.select do |ref|
          next unless ref.is_a?(InternalFragmentReference)

          !id_defined?(ref.target_id)
        end
      end

      # Get statistics
      def statistics
        {
          total_ids: @available_ids.size,
          total_references: @internal_references.size + @external_references.size,
          internal_references: @internal_references.size,
          external_references: @external_references.size,
          unresolved_internal: unresolved_internal_references.size,
          references_by_type: references_by_type.transform_values(&:size),
        }
      end

      # Export manifest for consumer processing
      def to_h
        {
          source_document: @source_document,
          available_ids: @available_ids.map(&:to_h),
          internal_references: @internal_references.map(&:to_h),
          external_references: @external_references.map(&:to_h),
          statistics: statistics,
        }
      end

      # Export as YAML for easy inspection
      def to_yaml
        require "yaml"
        to_h.to_yaml
      end

      # Export as JSON for programmatic processing
      def to_json(*_args)
        require "json"
        JSON.pretty_generate(to_h)
      end
    end
  end
end
