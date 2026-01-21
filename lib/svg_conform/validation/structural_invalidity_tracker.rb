# frozen_string_literal: true

require "set"

module SvgConform
  module Validation
    # Tracks structurally invalid nodes during validation
    # Separated from ValidationContext for better separation of concerns
    class StructuralInvalidityTracker
      def initialize(node_id_generator:)
        @structurally_invalid_node_ids = Set.new
        @node_id_generator = node_id_generator
      end

      # Mark a node as structurally invalid (e.g., invalid parent-child relationship)
      # Other requirements should skip attribute validation on these nodes
      # Also marks all descendants as invalid since they'll be removed with the parent
      def mark_node_structurally_invalid(node)
        node_id = @node_id_generator.call(node)
        return if node_id.nil? # Safety check

        @structurally_invalid_node_ids.add(node_id)

        # Mark all descendants as invalid too
        mark_descendants_invalid(node)
      end

      # Mark all descendants of a node as structurally invalid
      def mark_descendants_invalid(node)
        # In SAX mode, ElementProxy doesn't have children yet
        # Children will be validated individually and will check parent validity
        return unless node.respond_to?(:children) && node.children

        node.children.each do |child|
          child_id = @node_id_generator.call(child)
          next if child_id.nil? # Skip if can't generate ID

          @structurally_invalid_node_ids.add(child_id)
          # Recursively mark descendants
          mark_descendants_invalid(child)
        end
      end

      # Check if a node is structurally invalid
      def node_structurally_invalid?(node)
        node_id = @node_id_generator.call(node)
        return false if node_id.nil? # Safety check

        @structurally_invalid_node_ids.include?(node_id)
      end

      # Clear all tracked invalid nodes
      def clear
        @structurally_invalid_node_ids.clear
      end

      # Get the count of structurally invalid nodes
      def count
        @structurally_invalid_node_ids.size
      end
    end
  end
end
