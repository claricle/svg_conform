# frozen_string_literal: true

module SvgConform
  # Shared helper methods for working with XML nodes
  #
  # This module provides common utilities used by both requirements
  # and remediations to avoid code duplication and ensure consistency.
  module NodeHelpers
    # Check if a node is an element
    # @param node [Object] the node to check
    # @return [Boolean] true if the node is an element
    def element?(node)
      node.respond_to?(:name) && !node.name.nil?
    end

    # Check if a node is text
    # @param node [Object] the node to check
    # @return [Boolean] true if the node is text
    def text?(node)
      node.respond_to?(:text?) && node.text?
    end

    # Get attribute value from a node
    # @param node [Object] the node
    # @param name [String] attribute name
    # @return [String, nil] attribute value or nil
    def get_attribute(node, name)
      return nil unless node.respond_to?(:[])

      node[name]
    end

    # Set attribute value on a node
    # @param node [Object] the node
    # @param name [String] attribute name
    # @param value [String] attribute value
    # @return [Boolean] true if successful
    def set_attribute(node, name, value)
      return unless node.respond_to?(:[]=)

      node[name] = value
      true
    end

    # Check if node has an attribute
    # @param node [Object] the node
    # @param name [String] attribute name
    # @return [Boolean] true if attribute exists
    def has_attribute?(node, name)
      return false unless node.respond_to?(:[])

      !node[name].nil?
    end

    # Remove attribute from a node
    # @param node [Object] the node
    # @param name [String] attribute name
    # @return [Boolean] true if successful
    def remove_attribute(node, name)
      if node.respond_to?(:remove_attribute)
        node.remove_attribute(name)
        true
      elsif node.respond_to?(:[]=) && node.respond_to?(:[])
        # Fallback for bracket notation
        node[name] = nil
        true
      else
        false
      end
    end
  end
end
