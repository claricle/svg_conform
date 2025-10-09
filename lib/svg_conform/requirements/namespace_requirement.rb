# frozen_string_literal: true

require_relative "base_requirement"

module SvgConform
  module Requirements
    # Validates that SVG documents have proper namespace declarations
    class NamespaceRequirement < BaseRequirement
      attribute :type, :string, default: -> { "NamespaceRequirement" }
      attribute :allowed_namespaces, :string, collection: true, default: -> {
        ["http://www.w3.org/2000/svg"]
      }
      attribute :disallowed_namespaces, :string, collection: true, default: -> {
        []
      }
      attribute :required_namespace, :string, default: "http://www.w3.org/2000/svg"
      attribute :allow_rdf_metadata, :boolean, default: false

      # RDF-related namespaces commonly found in SVG metadata
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
        map "allowed_namespaces", to: :allowed_namespaces
        map "disallowed_namespaces", to: :disallowed_namespaces
        map "required_namespace", to: :required_namespace
        map "allow_rdf_metadata", to: :allow_rdf_metadata
      end

      def validate_document(document, context)
        root = document.root
        return unless root

        # Check if root element is svg
        unless root.name == "svg"
          context.add_error(
            requirement: self,
            node: root,
            message: "Root element must be 'svg'",
            data: { element_name: root.name },
          )
          return
        end

        # Check for SVG namespace - Moxml handles namespace differently
        svg_namespace = nil

        # Try to get namespace from Moxml's namespace method
        if root.respond_to?(:namespace) && root.namespace
          namespace_str = root.namespace.to_s
          # Extract the URI from the namespace string like 'xmlns="http://www.w3.org/2000/svg"'
          svg_namespace = ::Regexp.last_match(1) if namespace_str =~ /xmlns="([^"]+)"/
        end

        # Fallback to checking xmlns attribute
        svg_namespace ||= get_attribute(root, "xmlns")

        # Default namespace (empty string) should be treated as SVG namespace
        svg_namespace = "" if svg_namespace.nil?

        # Check against allowed namespaces if configured
        if allowed_namespaces && !allowed_namespaces.empty? && !allowed_namespaces.include?(svg_namespace)
          context.add_error(
            requirement: self,
            node: root,
            message: "Namespace '#{svg_namespace}' is not allowed. Only #{allowed_namespaces.join(', ')} are permitted",
            data: {
              current_namespace: svg_namespace,
              allowed_namespaces: allowed_namespaces,
            },
          )
          return
        end

        # Check against disallowed namespaces if configured (legacy support)
        if disallowed_namespaces && !disallowed_namespaces.empty? && disallowed_namespaces.include?(svg_namespace)
          context.add_error(
            requirement: self,
            node: root,
            message: "Namespace '#{svg_namespace}' is not allowed",
            data: {
              current_namespace: svg_namespace,
              disallowed_namespaces: disallowed_namespaces,
            },
          )
          return
        end

        # Default behavior: require SVG namespace
        unless allowed_namespaces.empty? && disallowed_namespaces.empty?
          # Now check all elements in the document for namespace violations
          check_all_elements(document, context)
          return
        end

        return if svg_namespace == "http://www.w3.org/2000/svg"

        context.add_error(
          requirement: self,
          node: root,
          message: "SVG namespace declaration missing or incorrect",
          data: {
            current_namespace: svg_namespace,
            expected_namespace: "http://www.w3.org/2000/svg",
          },
        )

        # Also check all elements for namespace violations
        check_all_elements(document, context)
      end

      def check(node, context)
        return unless element?(node)

        # Debug: Check all elements
        puts "DEBUG: Checking element: #{node.name}" if node.name.include?(":")

        # Check if this element has a namespace
        element_namespace = nil

        # Try to get namespace from the element
        if node.respond_to?(:namespace) && node.namespace
          namespace_str = node.namespace.to_s
          puts "DEBUG: namespace_str = #{namespace_str}" if node.name.include?(":")
          # Extract the URI from the namespace string
          element_namespace = ::Regexp.last_match(1) if namespace_str =~ /xmlns[^=]*="([^"]+)"/
        end

        # If no namespace found, check if element has a prefix (indicating it's namespaced)
        if element_namespace.nil? && node.name.include?(":")
          prefix = node.name.split(":").first
          puts "DEBUG: Found prefixed element #{node.name}, prefix = #{prefix}"
          element_namespace = find_namespace_uri_for_prefix(node, prefix)
          puts "DEBUG: Found namespace URI = #{element_namespace}"
        end

        # Skip if no namespace (default SVG namespace)
        if element_namespace.nil? || element_namespace.empty?
          puts "DEBUG: Skipping #{node.name} - no namespace found" if node.name.include?(":")
          return
        end

        puts "DEBUG: Element #{node.name} has namespace #{element_namespace}"

        # Check against allowed namespaces if configured
        # If allow_rdf_metadata is enabled, also allow RDF namespaces
        effective_allowed_namespaces = allowed_namespaces
        if allow_rdf_metadata
          effective_allowed_namespaces = allowed_namespaces + RDF_NAMESPACES
        end

        if effective_allowed_namespaces && !effective_allowed_namespaces.empty? && !effective_allowed_namespaces.include?(element_namespace)
          puts "DEBUG: Adding error for disallowed namespace #{element_namespace}"
          context.add_error(
            requirement_id: id,
            message: "The namespace #{element_namespace} is not permitted for svg elements.",
            node: node,
            severity: :error,
            data: {
              element_name: node.name,
              namespace: element_namespace,
              allowed_namespaces: effective_allowed_namespaces,
            },
          )
          return
        end

        # Check against disallowed namespaces if configured
        return unless disallowed_namespaces && !disallowed_namespaces.empty? && disallowed_namespaces.include?(element_namespace)

        puts "DEBUG: Adding error for explicitly disallowed namespace #{element_namespace}"
        context.add_error(
          requirement_id: id,
          message: "The namespace #{element_namespace} is not permitted for svg elements.",
          node: node,
          severity: :error,
          data: {
            element_name: node.name,
            namespace: element_namespace,
            disallowed_namespaces: disallowed_namespaces,
          },
        )
      end

      private

      def check_all_elements(document, context)
        # Recursively check all elements in the document
        traverse_elements(document.root, context)
      end

      def traverse_elements(node, context)
        return unless node

        # Check this element
        check_element_namespace(node, context) if element?(node)

        # Recursively check children
        if node.respond_to?(:children)
          node.children.each { |child| traverse_elements(child, context) }
        elsif node.respond_to?(:elements)
          node.elements.each { |child| traverse_elements(child, context) }
        end
      end

      def check_element_namespace(node, context)
        return unless element?(node)

        # Check if this element has a namespace
        element_namespace = nil

        # Try to get namespace from the element
        if node.respond_to?(:namespace) && node.namespace
          namespace_str = node.namespace.to_s
          # Extract the URI from the namespace string
          element_namespace = ::Regexp.last_match(1) if namespace_str =~ /xmlns[^=]*="([^"]+)"/
        end

        # If no namespace found, check if element has a prefix (indicating it's namespaced)
        if element_namespace.nil? && node.name.include?(":")
          prefix = node.name.split(":").first
          element_namespace = find_namespace_uri_for_prefix(node, prefix)
        end

        # Skip if no namespace (default SVG namespace)
        return if element_namespace.nil? || element_namespace.empty?

        # Check against allowed namespaces if configured
        # If allow_rdf_metadata is enabled, also allow RDF namespaces
        effective_allowed_namespaces = allowed_namespaces
        if allow_rdf_metadata
          effective_allowed_namespaces = allowed_namespaces + RDF_NAMESPACES
        end

        if effective_allowed_namespaces && !effective_allowed_namespaces.empty? && !effective_allowed_namespaces.include?(element_namespace)
          context.add_error(
            requirement_id: id,
            message: "The namespace #{element_namespace} is not permitted for svg elements.",
            node: node,
            severity: :error,
            data: {
              element_name: node.name,
              namespace: element_namespace,
              allowed_namespaces: effective_allowed_namespaces,
            },
          )
          return
        end

        # Check against disallowed namespaces if configured
        return unless disallowed_namespaces && !disallowed_namespaces.empty? && disallowed_namespaces.include?(element_namespace)

        context.add_error(
          requirement_id: id,
          message: "The namespace #{element_namespace} is not permitted for svg elements.",
          node: node,
          severity: :error,
          data: {
            element_name: node.name,
            namespace: element_namespace,
            disallowed_namespaces: disallowed_namespaces,
          },
        )
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
    end
  end
end
