# frozen_string_literal: true

require_relative "base_requirement"
require_relative "element_requirement_config"

module SvgConform
  module Requirements
    # Validates that only allowed SVG elements and their attributes are used
    class AllowedElementsRequirement < BaseRequirement
      attribute :type, :string, default: -> { "AllowedElementsRequirement" }
      attribute :element_configs, ElementRequirementConfig, collection: true, default: -> {
        []
      }
      attribute :disallowed_elements, :string, collection: true, default: -> {
        []
      }
      attribute :check_attributes, :boolean, default: false
      attribute :check_invalid_attributes, :boolean, default: false
      attribute :check_parent_child, :boolean, default: false
      attribute :parent_child_rules, :string, default: -> { {} }
      attribute :skip_foreign_namespaces, :boolean, default: false
      attribute :allowed_namespaces, :string, collection: true, default: -> {
        []
      }
      attribute :allow_rdf_metadata, :boolean, default: false

      # RDF-related namespaces (same as in NamespaceRequirement for consistency)
      RDF_NAMESPACES = [
        "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        "http://creativecommons.org/ns#",
        "http://purl.org/dc/elements/1.1/",
        "http://purl.org/dc/dcmitype/",
        "http://www.w3.org/2000/01/rdf-schema#",
      ].freeze

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "type", to: :type
        map "element_configs", to: :element_configs
        map "disallowed_elements", to: :disallowed_elements
        map "check_attributes", to: :check_attributes
        map "check_invalid_attributes", to: :check_invalid_attributes
        map "check_parent_child", to: :check_parent_child
        map "skip_foreign_namespaces", to: :skip_foreign_namespaces
        map "allowed_namespaces", to: :allowed_namespaces
        map "allow_rdf_metadata", to: :allow_rdf_metadata
      end

      def check(node, context)
        return unless element?(node)

        # Skip foreign namespace elements if configured (let NamespaceRequirement handle them)
        if skip_foreign_namespaces && foreign_namespace?(node)
          return
        end

        element_name = node.name

        # Check if element is explicitly disallowed
        if disallowed_element?(element_name)
          context.add_error(
            requirement_id: id,
            message: "Element '#{element_name}' is not allowed in this profile",
            node: node,
            severity: :error,
            data: { element: element_name },
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
              data: { element: element_name, parent: parent_name },
            )
            # Mark node AND descendants as structurally invalid
            # svgcheck does not validate attributes of forbidden children - just reports one error
            context.mark_node_structurally_invalid(node)
            return
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
              data: { element: element_name },
            )
            # Mark as structurally invalid so children aren't validated
            # (matches svgcheck behavior: invalid element removed with all children)
            context.mark_node_structurally_invalid(node)
            return
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
            severity: :error,
          )
        end
      end

      private

      def disallowed_element?(element_name)
        disallowed_elements&.include?(element_name) || false
      end

      def invalid_parent_child?(parent_name, child_name)
        return false unless element_configs&.any?

        # Find the configuration for the parent element
        parent_config = element_configs.find do |config|
          config.tag == parent_name
        end
        return false unless parent_config

        # If allowed_children is defined and not empty, use it
        if parent_config.allowed_children&.any?
          # Child must be in the allowed list
          return !parent_config.allowed_children.include?(child_name)
        end

        # No restrictions defined for this parent
        false
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

        element_config = element_configs.find do |config|
          config.tag == element_name
        end

        return errors unless element_config&.attr

        allowed_attrs = []
        disallowed_attrs = []

        # Parse attributes, separating allowed from disallowed (prefixed with !)
        element_config.attr.each do |attribute|
          if attribute.start_with?("!")
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
          next if attr_name.start_with?("xmlns:")
          next if attr_name.start_with?("xml:")

          # Skip namespaced attributes - they should be handled by NamespaceAttributesRequirement
          next if attr.namespace

          # Check if explicitly disallowed
          if disallowed_attrs.include?(attr_name)
            errors << {
              type: :explicitly_disallowed,
              attribute: attr_name,
              message: "Attribute '#{attr_name}' is explicitly disallowed on element '#{element_name}'",
            }
            next
          end

          # Check if not in allowed list
          next if allowed_attrs.include?(attr_name)

          errors << {
            type: :not_allowed,
            attribute: attr_name,
            message: "Attribute '#{attr_name}' is not allowed on element '#{element_name}'",
          }
        end

        errors
      end

      def collect_global_disallowed_errors(node)
        errors = []

        # Check for globally disallowed attributes (using * tag)
        return errors unless element_configs&.any?

        global_config = element_configs.find { |config| config.tag == "*" }
        return errors unless global_config&.attr

        global_disallowed = []
        global_config.attr.each do |attribute|
          global_disallowed << attribute[1..].downcase if attribute.start_with?("!")
        end

        return errors if global_disallowed.empty?

        node.attributes.each do |attr|
          attr_name = attr.name.downcase
          next unless global_disallowed.include?(attr_name)

          errors << {
            type: :globally_disallowed,
            attribute: attr_name,
            message: "Attribute '#{attr_name}' is globally disallowed in this profile",
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
          prioritized << if attr_errors.any? do |e|
            e[:type] == :globally_disallowed
          end
                           attr_errors.find do |e|
                             e[:type] == :globally_disallowed
                           end
                         elsif attr_errors.any? do |e|
                           e[:type] == :explicitly_disallowed
                         end
                           attr_errors.find do |e|
                             e[:type] == :explicitly_disallowed
                           end
                         else
                           attr_errors.find { |e| e[:type] == :not_allowed }
                         end
        end

        prioritized
      end

      def should_check_node?(node, context = nil)
        return false unless element?(node)
        return false if context&.node_structurally_invalid?(node)

        true
      end

      def foreign_namespace?(node)
        return false unless skip_foreign_namespaces

        # Check if element has a namespace
        element_namespace = get_element_namespace(node)

        # No namespace or empty namespace means SVG namespace (default)
        return false if element_namespace.nil? || element_namespace.empty?

        # Check if namespace is in allowed list
        # If allow_rdf_metadata is enabled, also allow RDF namespaces
        effective_allowed_namespaces = allowed_namespaces
        if allow_rdf_metadata
          effective_allowed_namespaces = allowed_namespaces + RDF_NAMESPACES
        end

        return false if effective_allowed_namespaces.empty?

        !effective_allowed_namespaces.include?(element_namespace)
      end

      def get_element_namespace(node)
        # Try to get namespace from the element
        if node.respond_to?(:namespace) && node.namespace
          namespace_str = node.namespace.to_s
          # Extract the URI from the namespace string
          if namespace_str =~ /xmlns[^=]*="([^"]+)"/
            return ::Regexp.last_match(1)
          end
        end

        # If no namespace found, check if element has a prefix (indicating it's namespaced)
        if node.name.include?(":")
          prefix = node.name.split(":").first
          return find_namespace_uri_for_prefix(node, prefix)
        end

        nil
      end

      def find_namespace_uri_for_prefix(node, prefix)
        # Check current node and ancestors for namespace declarations
        current = node
        while current
          # Check for xmlns:prefix attribute
          xmlns_attr = "xmlns:#{prefix}"
          if current.respond_to?(:attributes) && current.attributes[xmlns_attr]
            return current.attributes[xmlns_attr]
          end

          # Check using get_attribute method
          namespace_uri = get_attribute(current, xmlns_attr)
          return namespace_uri if namespace_uri

          # Move to parent
          current = current.respond_to?(:parent) ? current.parent : nil
        end

        nil
      end
    end
  end
end
