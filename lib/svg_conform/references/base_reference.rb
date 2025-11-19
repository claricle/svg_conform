# frozen_string_literal: true

require "lutaml/model"

module SvgConform
  module References
    # Base class for all reference types
    class BaseReference < Lutaml::Model::Serializable
      attribute :value, :string
      attribute :element_name, :string
      attribute :attribute_name, :string
      attribute :line_number, :integer
      attribute :column_number, :integer

      yaml do
        map "value", to: :value
        map "element_name", to: :element_name
        map "attribute_name", to: :attribute_name
        map "line_number", to: :line_number
        map "column_number", to: :column_number
      end

      json do
        map "value", to: :value
        map "element_name", to: :element_name
        map "attribute_name", to: :attribute_name
        map "line_number", to: :line_number
        map "column_number", to: :column_number
      end

      # Abstract method - defines validation scope
      def validation_scope
        raise NotImplementedError, "Subclasses must define validation scope"
      end

      # Can this reference be validated internally by svg_conform?
      def internally_validatable?
        validation_scope == :internal
      end

      # Should this be deferred to consumer for validation?
      def requires_consumer_validation?
        validation_scope == :external
      end

      def to_h
        {
          type: self.class.name.split("::").last,
          value: value,
          element_name: element_name,
          attribute_name: attribute_name,
          line_number: line_number,
          column_number: column_number,
          validation_scope: validation_scope,
        }
      end
    end

    # Internal SVG element reference (e.g., #element-id)
    class InternalFragmentReference < BaseReference
      def validation_scope
        :internal
      end

      def target_id
        value.sub(/^#/, "")
      end
    end

    # External URL reference (http://, https://)
    class ExternalUrlReference < BaseReference
      def validation_scope
        :external
      end

      def protocol
        require "uri"
        URI.parse(value).scheme
      rescue StandardError
        nil
      end
    end

    # URN reference (urn:*)
    class UrnReference < BaseReference
      def validation_scope
        :external
      end

      def namespace
        value.split(":")[1]
      rescue StandardError
        nil
      end
    end

    # Relative path reference (could be internal or external depending on context)
    class RelativePathReference < BaseReference
      def validation_scope
        :external
      end

      def has_fragment?
        value.include?("#")
      end

      def path_component
        value.split("#").first
      end

      def fragment_component
        parts = value.split("#")
        parts.size > 1 ? parts.last : nil
      end
    end

    # Data URI reference (data:*)
    class DataUriReference < BaseReference
      def validation_scope
        :internal
      end

      def media_type
        # Extract media type from data URI
        match = value.match(%r{^data:([^;,]+)})
        match ? match[1] : nil
      end
    end
  end
end