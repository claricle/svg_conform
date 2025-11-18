# frozen_string_literal: true

require_relative "base_requirement"

module SvgConform
  module Requirements
    # Validates that elements don't have attributes from disallowed namespaces
    # or only have attributes from allowed namespaces (whitelist mode)
    class NamespaceAttributesRequirement < BaseRequirement
      attribute :type, :string, default: -> { "NamespaceAttributesRequirement" }
      attribute :disallowed_namespaces, :string, collection: true, default: -> {
        []
      }
      attribute :allowed_namespaces, :string, collection: true, default: -> {
        []
      }
      attribute :exempt_elements, :string, collection: true, default: -> { [] }

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "type", to: :type
        map "disallowed_namespaces", to: :disallowed_namespaces
        map "allowed_namespaces", to: :allowed_namespaces
        map "exempt_elements", to: :exempt_elements
      end

      def check(node, context)
        return unless element?(node)

        # Skip validation for exempt elements (e.g., RDF metadata elements)
        return if exempt_elements.include?(node.name)

        # Try to get attributes using different methods depending on what's available
        if node.respond_to?(:attribute_nodes)
          # Use attribute_nodes if available (Nokogiri style)
          check_attribute_nodes(node, context)
        elsif node.respond_to?(:attributes)
          # Fallback to attributes method (Moxml style)
          check_attributes_hash(node, context)
        end
      end

      def validate_sax_element(element, context)
        # Skip validation for exempt elements (e.g., RDF metadata elements)
        return if exempt_elements.include?(element.name)

        # Check all attributes for namespace violations
        element.attributes.each do |attr|
          check_sax_attribute(attr, element, context)
        end
      end

      private

      def check_sax_attribute(attr, element, context)
        attr_name = attr.name

        # Check if this is a namespaced attribute by looking for colon in name
        return unless attr_name.include?(":")

        prefix, = attr_name.split(":", 2)

        # Find the namespace URI for this prefix by walking up parent chain
        namespace_uri = find_namespace_uri_sax(element, prefix)
        return unless namespace_uri

        # Determine if this namespace is invalid based on configuration
        invalid_namespace = if allowed_namespaces.empty?
                             # Blacklist mode: disallowed namespaces are forbidden
                             disallowed_namespaces.include?(namespace_uri)
                           else
                             # Whitelist mode: only allowed namespaces are permitted
                             !allowed_namespaces.include?(namespace_uri)
                           end

        return unless invalid_namespace

        context.add_error(
          requirement_id: id,
          message: "Element '#{element.name}' does not allow attributes with namespace '#{namespace_uri}'",
          node: element,
          severity: :error,
          data: { attribute: attr_name, namespace: namespace_uri }
        )
      end

      def find_namespace_uri_sax(element, prefix)
        # Check current element and ancestors for xmlns:prefix declarations
        current = element
        while current
          # Check for xmlns:prefix attribute in raw_attributes
          xmlns_value = current.raw_attributes["xmlns:#{prefix}"]
          return xmlns_value if xmlns_value

          # Move to parent
          current = current.parent
        end

        nil
      end

      private

      def check_attribute_nodes(node, context)
        node.attribute_nodes.each do |attr|
          # Check if attribute has a namespace
          namespace_uri = attr.namespace&.href
          next unless namespace_uri

          # Determine if this namespace is invalid based on configuration
          invalid_namespace = if allowed_namespaces.empty?
                                # Blacklist mode: disallowed namespaces are forbidden
                                disallowed_namespaces.include?(namespace_uri)
                              else
                                # Whitelist mode: only allowed namespaces are permitted
                                !allowed_namespaces.include?(namespace_uri)
                              end

          next unless invalid_namespace

          # Get the full attribute name with prefix if available
          attr_name = if attr.respond_to?(:namespace) && attr.namespace&.prefix
                        "#{attr.namespace.prefix}:#{attr.name}"
                      else
                        attr.name
                      end

          context.add_error(
            requirement_id: id,
            message: "Element '#{node.name}' does not allow attributes with namespace '#{namespace_uri}'",
            node: node,
            severity: :error,
            data: { attribute: attr_name, namespace: namespace_uri },
          )
        end
      end

      def check_attributes_hash(node, context)
        return unless node.respond_to?(:attributes)

        attributes = node.attributes

        # Handle both Hash and Array cases
        if attributes.respond_to?(:each_key)
          # Hash case
          attributes.each_key do |name|
            check_attribute_name(name, node, context)
          end
        elsif attributes.respond_to?(:each)
          # Array case - iterate over attribute objects
          attributes.each do |attr|
            check_moxml_attribute(attr, node, context)
          end
        end
      end

      def check_moxml_attribute(attr, node, context)
        # For Moxml attributes, check if they have namespace information
        if attr.respond_to?(:namespace) && attr.namespace
          namespace_uri = if attr.namespace.respond_to?(:href)
                            attr.namespace.href
                          elsif attr.namespace.respond_to?(:uri)
                            attr.namespace.uri
                          else
                            attr.namespace.to_s
                          end

          # Skip if no namespace URI
          return unless namespace_uri && !namespace_uri.empty?

          # Determine if this namespace is invalid based on configuration
          invalid_namespace = if allowed_namespaces.empty?
                                # Blacklist mode: disallowed namespaces are forbidden
                                disallowed_namespaces.include?(namespace_uri)
                              else
                                # Whitelist mode: only allowed namespaces are permitted
                                !allowed_namespaces.include?(namespace_uri)
                              end

          return unless invalid_namespace

          # Get the full attribute name with prefix if available
          attr_name = if attr.namespace.respond_to?(:prefix) && attr.namespace.prefix
                        "#{attr.namespace.prefix}:#{attr.name}"
                      else
                        attr.name
                      end

          context.add_error(
            requirement_id: id,
            message: "Element '#{node.name}' does not allow attributes with namespace '#{namespace_uri}'",
            node: node,
            severity: :error,
            data: { attribute: attr_name, namespace: namespace_uri },
          )
        else
          # Fallback to name-based checking for attributes without namespace objects
          name = attr.respond_to?(:name) ? attr.name : attr.to_s
          check_attribute_name(name, node, context)
        end
      end

      def check_attribute_name(name, node, context)
        # Convert name to string if it's not already
        name_str = name.to_s

        # Check if this is a namespaced attribute by looking for colon in name
        return unless name_str.include?(":")

        prefix, = name_str.split(":", 2)

        # Find the namespace URI for this prefix
        namespace_uri = find_namespace_uri(node, prefix)

        return unless namespace_uri

        # Determine if this namespace is invalid based on configuration
        invalid_namespace = if allowed_namespaces.empty?
                              # Blacklist mode: disallowed namespaces are forbidden
                              disallowed_namespaces.include?(namespace_uri)
                            else
                              # Whitelist mode: only allowed namespaces are permitted
                              !allowed_namespaces.include?(namespace_uri)
                            end

        return unless invalid_namespace

        context.add_error(
          requirement_id: id,
          message: "Element '#{node.name}' does not allow attributes with namespace '#{namespace_uri}'",
          node: node,
          severity: :error,
          data: { attribute: name, namespace: namespace_uri },
        )
      end

      def find_namespace_uri(node, prefix)
        # Check current node's namespace definitions
        current = node
        while current.respond_to?(:parent)
          if current.respond_to?(:namespace_definitions)
            ns_def = current.namespace_definitions.find do |ns|
              ns.prefix == prefix
            end
            if ns_def
              return ns_def.uri if ns_def.respond_to?(:uri)
              return ns_def.href if ns_def.respond_to?(:href)

              return ns_def.to_s
            end
          end

          # Check if it's defined as an attribute (xmlns:prefix)
          xmlns_value = get_attribute(current, "xmlns:#{prefix}")
          return xmlns_value if xmlns_value

          # Move to parent, but break if parent is nil or doesn't respond to parent
          begin
            current = current.parent
          rescue StandardError
            break
          end
        end

        nil
      end
    end
  end
end
