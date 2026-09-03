# frozen_string_literal: true

require "set"
require_relative "base_remediation"

module SvgConform
  module Remediations
    # Remediation for removing disallowed namespace attributes and declarations
    class NamespaceAttributeRemediation < BaseRemediation
      attribute :type, :string, default: -> { "NamespaceAttributeRemediation" }
      attribute :disallowed_namespaces, :string, collection: true, default: -> {
        []
      }
      attribute :allowed_namespaces, :string, collection: true, default: -> {
        []
      }

      yaml do
        map "disallowed_namespaces", to: :disallowed_namespaces
        map "allowed_namespaces", to: :allowed_namespaces
      end

      def apply(document, _context)
        changes = []
        removed_namespaces = Set.new

        # First pass: remove disallowed namespace attributes
        document.traverse do |node|
          next unless element?(node)

          changes.concat(remove_disallowed_attributes(node, removed_namespaces))
        end

        # Second pass: remove unused namespace declarations
        # Nokogiri/libxml2 cannot remove namespace declarations via DOM,
        # so we use string manipulation + reparse
        if removed_namespaces.any? || disallowed_namespaces.any?
          changes.concat(remove_namespace_declarations(document,
                                                       removed_namespaces))
        end

        changes
      end

      private

      def remove_disallowed_attributes(node, removed_namespaces)
        changes = []

        # Get all attributes that need to be checked
        attributes_to_remove = []

        if node.respond_to?(:attribute_nodes)
          # Use attribute_nodes if available (Nokogiri style)
          node.attribute_nodes.each do |attr|
            namespace_uri = attr.namespace&.href
            next unless namespace_uri

            if namespace_disallowed?(namespace_uri)
              attr_name = if attr.namespace&.prefix
                            "#{attr.namespace.prefix}:#{attr.name}"
                          else
                            attr.name
                          end
              attributes_to_remove << attr_name
              removed_namespaces.add(namespace_uri)
            end
          end
        elsif node.respond_to?(:attributes)
          # Fallback to attributes method
          attributes = node.attributes

          if attributes.respond_to?(:each_key)
            # Hash case
            attributes.each_key do |name|
              if should_remove_attribute_by_name?(name.to_s, node,
                                                  removed_namespaces)
                attributes_to_remove << name.to_s
              end
            end
          elsif attributes.respond_to?(:each)
            # Array case
            attributes.each do |attr|
              if should_remove_moxml_attribute?(attr, node, removed_namespaces)
                local_name = attr.respond_to?(:name) ? attr.name : attr.to_s
                ns_prefix = attr.respond_to?(:namespace) && attr.namespace&.respond_to?(:prefix) ? attr.namespace.prefix : nil
                attr_name = ns_prefix && !ns_prefix.empty? ? "#{ns_prefix}:#{local_name}" : local_name
                attributes_to_remove << attr_name
              end
            end
          end
        end

        # Remove the identified attributes
        attributes_to_remove.each do |attr_name|
          if remove_attribute(node, attr_name)
            changes << {
              type: :attribute_removed,
              description: "Removed disallowed namespace attribute '#{attr_name}'",
              node_name: node.name,
              attribute: attr_name,
            }
          end
        end

        changes
      end

      def remove_namespace_declarations(document, removed_namespaces)
        changes = []

        # Get current XML
        xml_str = document.to_xml

        # Build regex to remove xmlns declarations for disallowed namespaces
        # Match both removed namespaces (from attributes) and explicitly disallowed ones
        namespaces_to_remove = removed_namespaces.to_a + disallowed_namespaces

        namespaces_to_remove.uniq.each do |ns_identifier|
          # Try to match xmlns:prefix="anything" where prefix matches the identifier
          # or xmlns:prefix="identifier" where the URI matches
          pattern = /\s+xmlns:#{Regexp.escape(ns_identifier)}="[^"]*"/

          if xml_str.match?(pattern)
            xml_str = xml_str.gsub(pattern, "")
            changes << {
              type: :namespace_removed,
              description: "Removed unused namespace declaration 'xmlns:#{ns_identifier}'",
              node_name: "svg",
              attribute: "xmlns:#{ns_identifier}",
            }
          end
        end

        # Reparse the document to update the internal DOM
        # This is necessary because namespace declarations cannot be removed
        # from the DOM directly in Nokogiri/libxml2
        if changes.any?
          context = Moxml.new
          new_moxml_doc = context.parse(xml_str)

          # Replace the document's internal moxml_document
          # We need to use instance_variable_set since it's a private instance variable
          document.instance_variable_set(:@moxml_document, new_moxml_doc)
          document.clear_cache
        end

        changes
      end

      def namespace_disallowed?(namespace_uri)
        if allowed_namespaces.empty?
          # Blacklist mode: disallowed namespaces are forbidden
          disallowed_namespaces.include?(namespace_uri)
        else
          # Whitelist mode: only allowed namespaces are permitted
          !allowed_namespaces.include?(namespace_uri)
        end
      end

      def should_remove_attribute_by_name?(name, node, removed_namespaces)
        # Check if this is a namespaced attribute by looking for colon in name
        return false unless name.include?(":")

        prefix, = name.split(":", 2)

        # Find the namespace URI for this prefix
        namespace_uri = find_namespace_uri(node, prefix)

        return false unless namespace_uri

        if namespace_disallowed?(namespace_uri)
          removed_namespaces.add(namespace_uri)
          true
        else
          false
        end
      end

      def should_remove_moxml_attribute?(attr, node, removed_namespaces)
        if attr.respond_to?(:namespace) && attr.namespace
          namespace_uri = if attr.namespace.respond_to?(:href)
                            attr.namespace.href
                          elsif attr.namespace.respond_to?(:uri)
                            attr.namespace.uri
                          else
                            attr.namespace.to_s
                          end

          return false unless namespace_uri && !namespace_uri.empty?

          if namespace_disallowed?(namespace_uri)
            removed_namespaces.add(namespace_uri)
            true
          else
            false
          end
        else
          # Fallback to name-based checking
          name = attr.respond_to?(:name) ? attr.name : attr.to_s
          should_remove_attribute_by_name?(name, node, removed_namespaces)
        end
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
