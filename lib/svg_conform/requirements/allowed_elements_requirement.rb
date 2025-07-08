# frozen_string_literal: true

require_relative 'base_requirement'
require_relative 'element_requirement_config'

module SvgConform
  module Requirements
    # Validates that only allowed SVG elements and their attributes are used
    class AllowedElementsRequirement < BaseRequirement
      attribute :type, :string, default: -> { 'AllowedElementsRequirement' }
      attribute :element_configs, ElementRequirementConfig, collection: true, default: -> { [] }
      attribute :disallowed_elements, :string, collection: true, default: -> { [] }
      attribute :check_attributes, :boolean, default: false
      attribute :check_invalid_attributes, :boolean, default: false
      attribute :check_parent_child, :boolean, default: false
      attribute :parent_child_rules, :string, default: -> { {} }

      yaml do
        map 'id', to: :id
        map 'description', to: :description
        map 'type', to: :type
        map 'element_configs', to: :element_configs
        map 'disallowed_elements', to: :disallowed_elements
        map 'check_attributes', to: :check_attributes
        map 'check_invalid_attributes', to: :check_invalid_attributes
      end

      def check(node, context)
        return unless element?(node)

        element_name = node.name

        # Check if element is explicitly disallowed
        if disallowed_element?(element_name)
          context.add_error(
            requirement_id: id,
            message: "Element '#{element_name}' is not allowed in this profile",
            node: node,
            severity: :error,
            data: { element: element_name }
          )
          return
        end

        # Check parent-child relationships
        if check_parent_child && node.parent && element?(node.parent)
          parent_name = node.parent.name
          if invalid_parent_child?(parent_name, element_name)
            context.add_error(
              requirement_id: id,
              message: "The element '#{element_name}' is not allowed as a child of '#{parent_name}'",
              node: node,
              severity: :error,
              data: { element: element_name, parent: parent_name }
            )
          end
        end

        # Check if element is in allowed list
        if element_configs&.any?
          allowed_elements = element_configs.map(&:tag)
          unless allowed_elements.include?(element_name)
            context.add_error(
              requirement_id: id,
              message: "Element '#{element_name}' is not allowed in this profile",
              node: node,
              severity: :error,
              data: { element: element_name }
            )
          end
        end

        # Collect all potential attribute errors, then apply priority rules
        potential_errors = collect_attribute_errors(node)
        prioritized_errors = prioritize_errors(potential_errors)

        # Add the prioritized errors to the context
        prioritized_errors.each do |error|
          context.add_error(
            requirement_id: id,
            message: error[:message],
            node: node,
            severity: :error
          )
        end
      end

      private

      def disallowed_element?(element_name)
        disallowed_elements&.include?(element_name) || false
      end

      def invalid_parent_child?(parent_name, child_name)
        # Define invalid parent-child relationships based on SVG spec and svgcheck behavior
        invalid_relationships = {
          'desc' => %w[circle rect path ellipse line polyline polygon g use image text],
          'title' => %w[circle rect path ellipse line polyline polygon g use image text],
          'metadata' => %w[circle rect path ellipse line polyline polygon g use image text],
          'defs' => %w[clipPath font font-face missing-glyph glyph] # Based on svgcheck reports - these are NOT allowed in defs
        }

        # Check if this parent-child combination is invalid
        invalid_children = invalid_relationships[parent_name]
        return false unless invalid_children

        invalid_children.include?(child_name)
      end

      def collect_attribute_errors(node)
        errors = []
        node.name

        # Always collect global disallowed attributes first (highest priority)
        errors.concat(collect_global_disallowed_errors(node))

        # Collect element-specific attribute errors if enabled
        errors.concat(collect_element_attribute_errors(node)) if check_attributes

        errors
      end

      def collect_element_attribute_errors(node)
        errors = []
        element_name = node.name

        return errors unless element_configs&.any?

        element_config = element_configs.find { |config| config.tag == element_name }

        return errors unless element_config&.attr

        allowed_attrs = []
        disallowed_attrs = []

        # Parse attributes, separating allowed from disallowed (prefixed with !)
        element_config.attr.each do |attribute|
          if attribute.start_with?('!')
            disallowed_attrs << attribute[1..].downcase
          else
            allowed_attrs << attribute.downcase
          end
        end

        # Add common attributes that are allowed on all elements
        common_attrs = %w[id class style xmlns]
        allowed_attrs = (allowed_attrs + common_attrs).uniq

        # Add global properties that svgcheck allows on any element (from word_properties.py)
        global_properties = %w[
          about base baseprofile d break class content cx cy datatype height href
          label lang pathlength points preserveaspectratio property r rel resource
          rev role rotate rx ry space snapshottime transform typeof version width
          viewbox x x1 x2 y y1 y2 stroke stroke-width stroke-linecap stroke-linejoin
          stroke-miterlimit stroke-dasharray stroke-dashoffset stroke-opacity
          vector-effect viewport-fill display viewport-fill-opacity visibility
          image-rendering color-rendering shape-rendering text-rendering
          buffered-rendering solid-opacity solid-color color stop-color stop-opacity
          line-increment text-align display-align font-size font-family font-weight
          font-style font-variant direction unicode-bidi text-anchor fill fill-rule
          fill-opacity requiredfeatures requiredformats requiredextensions
          requiredfonts systemlanguage
        ]
        allowed_attrs = (allowed_attrs + global_properties).uniq

        node.attributes.each do |attr|
          attr_name = attr.name.downcase
          next if attr_name.start_with?('xmlns:')
          next if attr_name.start_with?('xml:')

          # Skip namespaced attributes - they should be handled by NamespaceAttributesRequirement
          next if attr.namespace

          # Check if explicitly disallowed
          if disallowed_attrs.include?(attr_name)
            errors << {
              type: :explicitly_disallowed,
              attribute: attr_name,
              message: "Attribute '#{attr_name}' is explicitly disallowed on element '#{element_name}'"
            }
            next
          end

          # Check if not in allowed list
          next if allowed_attrs.include?(attr_name)

          errors << {
            type: :not_allowed,
            attribute: attr_name,
            message: "Attribute '#{attr_name}' is not allowed on element '#{element_name}'"
          }
        end

        errors
      end

      def collect_global_disallowed_errors(node)
        errors = []

        # Check for globally disallowed attributes (using * tag)
        return errors unless element_configs&.any?

        global_config = element_configs.find { |config| config.tag == '*' }
        return errors unless global_config&.attr

        global_disallowed = []
        global_config.attr.each do |attribute|
          global_disallowed << attribute[1..].downcase if attribute.start_with?('!')
        end

        return errors if global_disallowed.empty?

        node.attributes.each do |attr|
          attr_name = attr.name.downcase
          next unless global_disallowed.include?(attr_name)

          errors << {
            type: :globally_disallowed,
            attribute: attr_name,
            message: "Attribute '#{attr_name}' is globally disallowed in this profile"
          }
        end

        errors
      end

      def prioritize_errors(errors)
        # Group errors by attribute name
        errors_by_attr = errors.group_by { |error| error[:attribute] }

        prioritized = []

        errors_by_attr.each_value do |attr_errors|
          # Priority order: globally_disallowed > explicitly_disallowed > not_allowed
          prioritized << if attr_errors.any? { |e| e[:type] == :globally_disallowed }
                           attr_errors.find { |e| e[:type] == :globally_disallowed }
                         elsif attr_errors.any? { |e| e[:type] == :explicitly_disallowed }
                           attr_errors.find { |e| e[:type] == :explicitly_disallowed }
                         else
                           attr_errors.find { |e| e[:type] == :not_allowed }
                         end
        end

        prioritized
      end

      def should_check_node?(node)
        element?(node)
      end
    end
  end
end
