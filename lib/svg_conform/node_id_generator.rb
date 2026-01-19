# frozen_string_literal: true

require_relative "comparison/node_id_cache_pool"

module SvgConform
  # Generates unique identifiers for nodes based on their path in the document.
  #
  # Uses path-based identification (e.g., "/svg[1]/rect[3]") that remains
  # stable across different traversals. Implements lazy cache population
  # for optimal performance.
  #
  # Uses shared cache pool for batch validation performance.
  class NodeIdGenerator
    # Initialize a new node ID generator
    #
    # @param document [Object] the document being validated
    def initialize(document)
      @document = document
      @node_id_cache = {}
      @cache_populated = false
    end

    # Generate a unique identifier for a node based on its path.
    #
    # Builds a stable path by walking up the parent chain.
    # Uses shared cache pool for batch validation reuse.
    #
    # @param node [Object] the node to generate an ID for
    # @return [String, nil] the node ID or nil if the node doesn't have a name
    def generate_id(node)
      return nil unless node.respond_to?(:name)

      # Try shared cache pool first (for batch validation reuse)
      if @document
        shared_cache = Comparison::NodeIdCachePool.get_or_create_cache(@document)
        cached_id = shared_cache[node]
        return cached_id if cached_id
      end

      # Populate cache for ALL nodes on first access (only if we have a document)
      # In SAX mode (@document is nil), we skip cache population and build paths on-demand
      unless @cache_populated
        if @document
          populate_cache
        else
          # In SAX mode, mark cache as populated to prevent future attempts
          @cache_populated = true
        end
      end

      # Try local cache lookup
      cached_id = @node_id_cache[node]
      return cached_id if cached_id

      # Fall back to building path if node not in cache
      # (happens when different traversals create different wrapper objects)
      build_node_path(node)
    end

    # Clear the cache (useful for testing or memory management)
    def clear_cache
      @node_id_cache.clear
      @cache_populated = false
    end

    private

    # Populate cache for all nodes using document.traverse with parent tracking.
    # Also populates shared cache pool for batch validation reuse.
    def populate_cache
      parent_stack = []
      counter_stack = [{}] # Stack of {element_name => count} hashes

      # Get shared cache pool for batch reuse
      shared_cache = @document ? Comparison::NodeIdCachePool.get_or_create_cache(@document) : @node_id_cache

      @document.traverse do |node|
        next unless node.respond_to?(:name) && node.name

        # Detect parent changes by checking node.parent
        current_parent = node.respond_to?(:parent) ? node.parent : nil

        # Adjust stack based on actual parent
        while parent_stack.size.positive? && !parent_stack.last.equal?(current_parent)
          parent_stack.pop
          counter_stack.pop
        end

        # If we have a new parent level, push it
        if current_parent && (parent_stack.empty? || !parent_stack.last.equal?(current_parent))
          parent_stack.push(current_parent)
          counter_stack.push({})
        end

        # Increment counter at current level
        current_counters = counter_stack.last || {}
        current_counters[node.name] ||= 0
        current_counters[node.name] += 1

        # Build path using original backward logic (for correctness)
        node_path = build_node_path(node)

        # Store in both local cache and shared cache pool
        @node_id_cache[node] = node_path
        shared_cache[node] = node_path if @document
      end
    end

    # Build path-based ID for a node.
    #
    # Traverses tree, building paths with position counting.
    # Uses backward traversal (walks up parent chain) for original logic compatibility.
    #
    # @param node [Object] the node to build a path for
    # @return [String] the path-based ID (e.g., "/svg[1]/rect[3]")
    def build_node_path(node)
      path_parts = []
      current = node

      while current
        if current.respond_to?(:name) && current.name
          # Count previous siblings of the same type for position (ORIGINAL LOGIC)
          position = 1
          if current.respond_to?(:previous_sibling)
            sibling = current.previous_sibling
            while sibling
              position += 1 if sibling.respond_to?(:name) && sibling.name == current.name
              sibling = sibling.previous_sibling if sibling.respond_to?(:previous_sibling)
            end
          end

          path_parts.unshift("#{current.name}[#{position}]")
        end

        # Stop if we reach the document root (doesn't have parent)
        break unless current.respond_to?(:parent)

        begin
          current = current.parent
        rescue NoMethodError
          # Parent method failed, we're at root
          break
        end

        break unless current
      end

      "/#{path_parts.join('/')}"
    end
  end
end
