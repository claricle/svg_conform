# frozen_string_literal: true

module SvgConform
  module Requirements
    # Shared namespace utilities for validation requirements
    #
    # This module provides common namespace-related functionality used across
    # multiple requirements, eliminating code duplication and ensuring consistency.
    #
    # @note This module is intended to be extended or used as a mixin by requirements
    module NamespaceUtilities
      # RDF-related namespaces commonly found in SVG metadata
      # These namespaces are allowed when allow_rdf_metadata is enabled
      RDF_NAMESPACES = [
        "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        "http://creativecommons.org/ns#",
        "http://purl.org/dc/elements/1.1/",
        "http://purl.org/dc/dcmitype/",
        "http://www.w3.org/2000/01/rdf-schema#",
      ].freeze

      module ClassMethods
        # Calculate effective allowed namespaces for validation
        #
        # Combines the base allowed_namespaces with RDF_NAMESPACES if
        # allow_rdf_metadata is enabled. This is a common pattern across
        # multiple requirements.
        #
        # @param allowed_namespaces [Array<String>] base allowed namespaces
        # @param allow_rdf_metadata [Boolean] whether to include RDF namespaces
        # @return [Array<String>] effective allowed namespaces
        def effective_allowed_namespaces(allowed_namespaces,
allow_rdf_metadata:)
          namespaces = allowed_namespaces.dup
          if allow_rdf_metadata
            namespaces += RDF_NAMESPACES
          end
          namespaces
        end

        # Check if an element's namespace is in the effective allowed list
        #
        # @param element_namespace [String, nil] the element's namespace URI
        # @param allowed_namespaces [Array<String>] base allowed namespaces
        # @param allow_rdf_metadata [Boolean] whether to include RDF namespaces
        # @return [Boolean] true if namespace is allowed
        def namespace_allowed?(element_namespace, allowed_namespaces,
allow_rdf_metadata:)
          return false if element_namespace.nil?

          effective = effective_allowed_namespaces(allowed_namespaces,
                                                   allow_rdf_metadata)
          return false if effective.empty?

          effective.include?(element_namespace)
        end

        # Check if namespace is foreign (not in allowed list)
        #
        # @param element_namespace [String, nil] the element's namespace URI
        # @param allowed_namespaces [Array<String>] base allowed namespaces
        # @param allow_rdf_metadata [Boolean] whether to include RDF namespaces
        # @return [Boolean] true if namespace is foreign
        def foreign_namespace?(element_namespace, allowed_namespaces,
allow_rdf_metadata:)
          return false if element_namespace.nil?

          !namespace_allowed?(element_namespace, allowed_namespaces,
                              allow_rdf_metadata)
        end
      end

      # Instance methods that delegate to class methods or provide instance-level functionality

      # Calculate effective allowed namespaces for validation
      #
      # @param allowed_namespaces [Array<String>] base allowed namespaces
      # @param allow_rdf_metadata [Boolean] whether to include RDF namespaces
      # @return [Array<String>] effective allowed namespaces
      def effective_allowed_namespaces(allowed_namespaces, allow_rdf_metadata:)
        # Direct implementation to avoid delegation issues
        namespaces = allowed_namespaces.dup
        if allow_rdf_metadata
          namespaces += RDF_NAMESPACES
        end
        namespaces
      end

      # Check if an element's namespace is in the effective allowed list
      #
      # @param element_namespace [String, nil] the element's namespace URI
      # @param allowed_namespaces [Array<String>] base allowed namespaces
      # @param allow_rdf_metadata [Boolean] whether to include RDF namespaces
      # @return [Boolean] true if namespace is allowed
      def namespace_allowed?(element_namespace, allowed_namespaces,
allow_rdf_metadata:)
        # Direct implementation to avoid delegation issues
        return false if element_namespace.nil?

        effective = effective_allowed_namespaces(allowed_namespaces,
                                                 allow_rdf_metadata: allow_rdf_metadata)
        return false if effective.empty?

        effective.include?(element_namespace)
      end

      # Check if namespace is foreign (not in allowed list)
      #
      # @param element_namespace [String, nil] the element's namespace URI
      # @param allowed_namespaces [Array<String>] base allowed namespaces
      # @param allow_rdf_metadata [Boolean] whether to include RDF namespaces
      # @return [Boolean] true if namespace is foreign
      def foreign_namespace?(element_namespace, allowed_namespaces,
allow_rdf_metadata:)
        # Direct implementation to avoid delegation issues
        return false if element_namespace.nil?

        effective = effective_allowed_namespaces(allowed_namespaces,
                                                 allow_rdf_metadata: allow_rdf_metadata)
        !effective.include?(element_namespace)
      end

      # Extract namespace URI from a node
      #
      # Handles different node types and namespace representations.
      # Returns the namespace URI as a string, or nil if not found.
      #
      # @param node [Object] the node to extract namespace from
      # @return [String, nil] the namespace URI or nil
      def extract_namespace_uri(node)
        return nil unless node.respond_to?(:namespace)

        # Try to get namespace from Moxml's namespace method
        if node.namespace
          namespace_str = node.namespace.to_s
          # Extract the URI from the namespace string like 'xmlns="http://www.w3.org/2000/svg"'
          if namespace_str =~ /xmlns="([^"]+)"/
            return ::Regexp.last_match(1)
          end
        end

        # Fallback to checking xmlns attribute
        if node.respond_to?(:attribute)
          attr = node.attribute("xmlns")
          return attr&.value
        end

        nil
      end

      # Check if a node has a foreign namespace
      #
      # This is a convenience method that combines namespace extraction
      # with the foreign namespace check.
      #
      # @param node [Object] the node to check
      # @param allowed_namespaces [Array<String>] base allowed namespaces (optional, uses instance attribute if nil)
      # @param allow_rdf_metadata [Boolean] whether to include RDF namespaces (optional, uses instance attribute if nil)
      # @return [Boolean] true if node has a foreign namespace
      def node_has_foreign_namespace?(node, allowed_namespaces = nil,
allow_rdf_metadata = nil)
        # Use instance attributes if not provided
        allowed_namespaces ||= @allowed_namespaces if instance_variable_defined?(:@allowed_namespaces)
        allow_rdf_metadata ||= @allow_rdf_metadata if instance_variable_defined?(:@allow_rdf_metadata)

        element_namespace = extract_namespace_uri(node)
        return false if element_namespace.nil?

        # Direct implementation to avoid delegation issues
        effective = effective_allowed_namespaces(allowed_namespaces,
                                                 allow_rdf_metadata: allow_rdf_metadata)
        return false if effective.empty?

        !effective.include?(element_namespace)
      end

      # SAX-specific namespace checking for element proxies
      #
      # During SAX parsing, element proxies have different structure.
      # This method handles SAX-specific namespace extraction.
      #
      # @param element [Hash] SAX element hash
      # @param allowed_namespaces [Array<String>] base allowed namespaces
      # @param allow_rdf [Boolean] whether to include RDF namespaces
      # @return [Boolean] true if element has a foreign namespace
      def foreign_namespace_sax?(element, allowed_namespaces, allow_rdf)
        return false unless element.is_a?(Hash)

        # Extract namespace from SAX element
        element_namespace = element[:namespace] || element["namespace"]
        foreign_namespace?(element_namespace, allowed_namespaces,
                           allow_rdf_metadata: allow_rdf)
      end

      class << self
        # When included, extend the class with class methods
        def included(base)
          base.extend(ClassMethods)
        end
      end
    end
  end
end
