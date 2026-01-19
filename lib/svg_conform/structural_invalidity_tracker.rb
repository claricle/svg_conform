# frozen_string_literal: true

require "set"

module SvgConform
  # Tracks structurally invalid nodes during validation.
  #
  # A node is marked as structurally invalid when it has an invalid
  # parent-child relationship (e.g., wrong element type as parent).
  # All descendants of structurally invalid nodes are also marked
  # as invalid since they will be removed with the parent.
  #
  # Other requirements should skip attribute validation on these nodes
  # since the structural issue will cause them to be removed anyway.
  class StructuralInvalidityTracker
    # Initialize a new tracker
    def initialize
      @structurally_invalid_node_ids = Set.new
    end

    # Mark a node as structurally invalid.
    #
    # Also marks all descendants as invalid since they'll be removed with the parent.
    #
    # @param node [Object] the node to mark
    # @param node_id_generator [NodeIdGenerator] generator for creating node IDs
    def mark_node_invalid(node, node_id_generator)
      node_id = node_id_generator.generate_id(node)
      return if node_id.nil? # Safety check

      @structurally_invalid_node_ids.add(node_id)

      # Mark all descendants as invalid too
      mark_descendants_invalid(node, node_id_generator)
    end

    # Check if a node is structurally invalid.
    #
    # @param node [Object] the node to check
    # @param node_id_generator [NodeIdGenerator] generator for creating node IDs
    # @return [Boolean] true if the node is structurally invalid
    def node_invalid?(node, node_id_generator)
      node_id = node_id_generator.generate_id(node)
      return false if node_id.nil? # Safety check

      @structurally_invalid_node_ids.include?(node_id)
    end

    # Get the count of structurally invalid nodes.
    # @return [Integer] the count
    def count
      @structurally_invalid_node_ids.size
    end

    # Check if tracker has any invalid nodes.
    # @return [Boolean] true if any nodes are tracked
    def any?
      @structurally_invalid_node_ids.any?
    end

    # Clear all tracked invalid nodes.
    def clear
      @structurally_invalid_node_ids.clear
    end

    # Get all tracked node IDs.
    # @return [Set] the set of node IDs
    def node_ids
      @structurally_invalid_node_ids.dup
    end

    private

    # Mark all descendants of a node as structurally invalid.
    #
    # In SAX mode, ElementProxy doesn't have children yet.
    # Children will be validated individually and will check parent validity.
    #
    # @param node [Object] the node whose descendants should be marked
    # @param node_id_generator [NodeIdGenerator] generator for creating node IDs
    def mark_descendants_invalid(node, node_id_generator)
      # In SAX mode, ElementProxy doesn't have children yet
      # Children will be validated individually and will check parent validity
      return unless node.respond_to?(:children) && node.children

      node.children.each do |child|
        child_id = node_id_generator.generate_id(child)
        next if child_id.nil? # Skip if can't generate ID

        @structurally_invalid_node_ids.add(child_id)
        # Recursively mark descendants
        mark_descendants_invalid(child, node_id_generator)
      end
    end
  end
end
