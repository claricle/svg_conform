# frozen_string_literal: true

require 'lutaml/model'

module SvgConform
  module Requirements
    # Represents an allowed SVG element configuration with its allowed attributes
    class ElementRequirementConfig < Lutaml::Model::Serializable
      attribute :tag, :string
      attribute :attr, :string, collection: true, default: -> { [] }
      attribute :allowed_children, :string, collection: true, default: -> { [] }

      yaml do
        map 'tag', to: :tag
        map 'attributes', to: :attr
        map 'allowed_children', to: :allowed_children
      end

      # Check if an attribute is allowed for this element
      def attribute_allowed?(attr_name)
        return false unless attr

        attr_name = attr_name.downcase

        # Common attributes that are allowed on all elements
        common_attrs = %w[id class style xmlns]
        return true if common_attrs.include?(attr_name)

        # Skip xmlns: and xml: prefixed attributes
        return true if attr_name.start_with?('xmlns:') || attr_name.start_with?('xml:')

        # Check if explicitly disallowed (prefixed with !)
        return false if attr.any? { |attribute| attribute.start_with?('!') && attribute[1..].downcase == attr_name }

        # Check if in allowed list
        attr.any? { |attribute| !attribute.start_with?('!') && attribute.downcase == attr_name }
      end

      # Get list of explicitly disallowed attributes (those prefixed with !)
      def disallowed_attributes
        return [] unless attr

        attr.filter_map do |attribute|
          attribute[1..].downcase if attribute.start_with?('!')
        end
      end

      # Get list of allowed attributes (those not prefixed with !)
      def allowed_attributes
        return [] unless attr

        allowed = attr.filter_map do |attribute|
          attribute.downcase unless attribute.start_with?('!')
        end

        # Add common attributes
        common_attrs = %w[id class style xmlns]
        (allowed + common_attrs).uniq
      end

      # Check if this is a global config (applies to all elements)
      def global_config?
        tag == '*'
      end

      def to_s
        "ElementRequirementConfig(#{tag}: #{attr&.join(', ') || 'none'})"
      end
    end
  end
end
