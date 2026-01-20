# frozen_string_literal: true

require_relative "base_remediation"
require "set"

module SvgConform
  module Remediations
    # Remediation action for namespace-related issues
    class NamespaceRemediation < BaseRemediation
      attribute :type, :string, default: -> { "NamespaceRemediation" }
      attribute :default_namespace, :string, default: "http://www.w3.org/2000/svg"
      attribute :allowed_namespaces, :string, collection: true, default: -> {
        ["http://www.w3.org/2000/svg", "http://www.w3.org/1999/xlink",
         "http://www.w3.org/XML/1998/namespace"]
      }
      attribute :remove_elements, :boolean, default: true
      attribute :remove_attributes, :boolean, default: true
      attribute :remove_declarations, :boolean, default: true

      yaml do
        map "default_namespace", to: :default_namespace
        map "allowed_namespaces", to: :allowed_namespaces
        map "remove_elements", to: :remove_elements
        map "remove_attributes", to: :remove_attributes
        map "remove_declarations", to: :remove_declarations
      end
      def apply(document, _context)
        changes = []
        default_namespace

        # Skip xmlns handling - assume it's already correct in most cases
        # (This avoids duplicate xmlns attribute issues)

        # Remove invalid namespace elements and attributes based on configuration
        nodes_to_remove = []

        document.traverse do |node|
          next unless element?(node)

          # Check if element has invalid namespace using Moxml's namespace API
          if remove_elements && node.respond_to?(:namespace) && node.namespace
            namespace_uri = get_namespace_uri(node.namespace)

            if namespace_uri && !allowed_namespaces.include?(namespace_uri)
              nodes_to_remove << node
              changes << {
                type: :element_removed,
                description: "Removed invalid namespace element: #{node.name} (#{namespace_uri})",
                node_name: node.name,
                namespace_uri: namespace_uri,
              }
              next # Skip attribute checking for elements we're removing
            end
          end

          # Remove invalid namespace attributes from all elements
          if remove_attributes && node.respond_to?(:attributes) && node.attributes
            invalid_attrs = []

            node.attributes.each do |attr_name, attr_value|
              # Handle both string keys and Moxml::Attribute objects
              name_str = attr_name.respond_to?(:name) ? attr_name.name : attr_name.to_s

              # For root SVG element, remove xmlns declarations for disallowed namespaces
              if remove_declarations && node.name == "svg" && name_str.start_with?("xmlns:")
                name_str.sub("xmlns:", "")
                value_str = attr_value.respond_to?(:value) ? attr_value.value : attr_value.to_s

                if !allowed_namespaces.include?(value_str)
                  invalid_attrs << name_str
                end
              end

              # For all elements, remove attributes with invalid namespaces
              # Check if attribute has namespace information (Moxml::Attribute objects)
              if attr_name.respond_to?(:namespace) && attr_name.namespace
                attr_namespace_uri = get_namespace_uri(attr_name.namespace)

                if attr_namespace_uri && !allowed_namespaces.include?(attr_namespace_uri)
                  invalid_attrs << name_str
                end
              end
            end

            # Remove invalid attributes
            invalid_attrs.each do |attr_name|
              remove_attribute(node, attr_name)
              description = if attr_name.start_with?("xmlns:")
                              "Removed invalid namespace declaration: #{attr_name}"
                            else
                              "Removed invalid namespace attribute: #{attr_name}"
                            end

              changes << {
                type: :attribute_removed,
                description: description,
                node_name: node.name,
                attribute_name: attr_name,
              }
            end
          end
        end

        # Remove invalid namespace elements
        nodes_to_remove.each do |node|
          remove_node(node)
        end

        # Clean up unused namespace declarations
        # Note: Moxml/Nokogiri don't support removing namespace declarations directly,
        # so we mark the document for post-processing during serialization
        cleanup_unused_namespace_declarations(document)

        changes
      end

      private

      def get_namespace_uri(namespace)
        # Extract URI from Moxml::Namespace object
        if namespace.respond_to?(:uri)
          namespace.uri
        elsif namespace.respond_to?(:to_s)
          # Extract URI from string representation if needed
          uri_match = namespace.to_s.match(/="([^"]+)"/)
          uri_match ? uri_match[1] : nil
        else
          nil
        end
      end

      def find_namespace_uri_for_prefix(node, prefix)
        # Check current node and ancestors for namespace declarations
        current = node
        while current
          # Check for xmlns:prefix attribute
          xmlns_attr = "xmlns:#{prefix}"
          return current.attributes[xmlns_attr] if current.respond_to?(:attributes) && current.attributes[xmlns_attr]

          # Check using get_attribute method
          namespace_uri = get_attribute(current, xmlns_attr)
          return namespace_uri if namespace_uri

          # Move to parent
          current = current.respond_to?(:parent) ? current.parent : nil
        end

        nil
      end

      def find_namespace_uri_for_attribute(node, prefix)
        # Same logic as find_namespace_uri_for_prefix
        find_namespace_uri_for_prefix(node, prefix)
      end

      def cleanup_unused_namespace_declarations(document)
        # Find which namespace prefixes are still in use
        used_prefixes = find_used_namespace_prefixes(document)

        # Get the root element
        root = document.respond_to?(:root) ? document.root : document
        return unless root.respond_to?(:namespace_definitions)

        # Get disallowed namespace prefixes
        disallowed_prefixes = root.namespace_definitions.filter_map do |ns|
          prefix = ns.respond_to?(:prefix) ? ns.prefix : nil
          uri = ns.respond_to?(:uri) ? ns.uri : (ns.respond_to?(:href) ? ns.href : nil)
          next if prefix.nil? || prefix.empty? # Skip default namespace
          next if allowed_namespaces.include?(uri) # Keep allowed namespaces
          next if used_prefixes.include?(prefix) # Keep prefixes still in use
          prefix
        end

        # Store the prefixes to remove on the document for later serialization
        # Try to store on Document wrapper first, fallback to moxml_document
        target = document.respond_to?(:instance_variable_set) ? document : root.document
        target.instance_variable_set(:@unused_namespace_prefixes, disallowed_prefixes) if target
      end

      def find_used_namespace_prefixes(document)
        used_prefixes = Set.new(["xml"]) # xml prefix is always reserved

        document.traverse do |node|
          next unless node.respond_to?(:name)

          # Check element name for namespace prefix
          if node.name.include?(":")
            prefix = node.name.split(":").first
            used_prefixes << prefix
          end

          # Check attributes for namespace prefixes
          if node.respond_to?(:attributes)
            node.attributes.each do |attr|
              attr_name = attr.respond_to?(:name) ? attr.name : attr.to_s
              if attr_name.include?(":")
                prefix = attr_name.split(":").first
                used_prefixes << prefix
              end
            end
          end
        end

        used_prefixes
      end
    end
  end
end
