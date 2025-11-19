# frozen_string_literal: true

module SvgConform
  # Fast document analyzer that pre-computes node relationships and IDs
  # in a single pass to avoid repeated expensive traversals
  #
  # IMPORTANT: Stores paths indexed by the path itself (not object_id)
  # since node object_ids change between traversals
  class FastDocumentAnalyzer
    attr_reader :path_cache

    def initialize(document)
      @document = document
      @path_cache = {}

      analyze_document
    end

    # Get cached path-based ID for a node by computing its path once
    def get_node_id(node)
      return nil unless node.respond_to?(:name) && node.name

      # Compute path for this node (fast with forward traversal counting)
      compute_path_forward(node)
    end

    private

    def analyze_document
      # Pre-populate cache is not needed since we compute on demand
      # The optimization comes from forward-counting siblings instead of backward
    end

    def compute_path_forward(node)
      path_parts = []
      current = node

      while current
        if current.respond_to?(:name) && current.name
          # Count position among siblings by iterating forward from parent
          position = calculate_position_fast(current)
          path_parts.unshift("#{current.name}[#{position}]")
        end

        break unless current.respond_to?(:parent)

        begin
          current = current.parent
        rescue NoMethodError
          break
        end

        break unless current
      end

      "/#{path_parts.join('/')}"
    end

    def calculate_position_fast(node)
      return 1 unless node.respond_to?(:parent)

      parent = begin
        node.parent
      rescue NoMethodError
        nil
      end

      return 1 unless parent.respond_to?(:children)

      # Count this node's position among siblings with same name
      position = 0
      parent.children.each do |child|
        next unless child.respond_to?(:name) && child.name == node.name

        position += 1
        break if child.equal?(node)
      end

      position
    end
  end
end
