# frozen_string_literal: true

module SvgConform
  # Builds an index of node positions in single forward pass
  # Replicates the exact logic of backward sibling traversal but computed forward
  class NodeIndexBuilder
    def initialize(document)
      @node_positions = {}
      build_index(document.root) if document.root
    end

    # Get position of node among its siblings with same name
    def get_position(node)
      @node_positions[node]
    end

    private

    # Build position index by traversing forward but tracking as if counting backward
    # This matches the original logic: position = count of (previous siblings with same name) + 1
    def build_index(node, parent_child_counter = nil)
      return unless node.respond_to?(:name) && node.name

      # If this is root or we don't have parent's counter, create new counter
      if parent_child_counter.nil?
        # This is the root - position is always 1
        @node_positions[node] = 1
      else
        # Increment counter for this node name
        parent_child_counter[node.name] ||= 0
        parent_child_counter[node.name] += 1
        @node_positions[node] = parent_child_counter[node.name]
      end

      # Process children with a fresh counter for this parent's children
      if node.respond_to?(:children)
        # Create new counter for children of this node
        child_counter = {}
        node.children.each do |child|
          # Only process nodes with name (skip text nodes, etc.)
          next unless child.respond_to?(:name) && child.name
          build_index(child, child_counter)
        end
      end
    end
  end
end
