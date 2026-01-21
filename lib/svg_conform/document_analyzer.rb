# frozen_string_literal: true

module SvgConform
  # Document analyzer that computes node IDs using forward counting
  # to avoid expensive backward sibling traversal.
  #
  # Uses parent.children iteration to calculate position among siblings,
  # which is more efficient than walking previous_sibling chain.
  class DocumentAnalyzer
    attr_reader :cache

    def initialize(document)
      @document = document
      @cache = {}
      populate_cache
    end

    # Get path-based ID for a node from cache
    def get_node_id(node)
      return nil unless node.respond_to?(:name) && node.name

      # Return cached ID or compute on-demand
      @cache[node.object_id] ||= compute_and_cache_path(node)
    end

    private

    def populate_cache
      parent_stack = []
      counter_stack = [{}] # Stack of {element_name => count} hashes

      @document.traverse do |node|
        next unless node.respond_to?(:name) && node.name

        # Detect parent changes by checking node.parent
        current_parent = node.respond_to?(:parent) ? node.parent : nil

        # Adjust stack based on actual parent
        while parent_stack.size.positive? && !parent_stack.last.equal?(current_parent)
          parent_stack.pop
          counter_stack.pop
        end

        # If we have a new parent level, push it (only if parent has a name)
        if current_parent.respond_to?(:name) && current_parent.name &&
            (parent_stack.empty? || !parent_stack.last.equal?(current_parent))
          parent_stack.push(current_parent)
          counter_stack.push({})
        end

        # Increment counter at current level
        current_counters = counter_stack.last || {}
        current_counters[node.name] ||= 0
        current_counters[node.name] += 1
        position = current_counters[node.name]

        # Build and cache path (only include parents with valid names)
        path_parts = parent_stack.map.with_index do |parent, idx|
          next unless parent.respond_to?(:name) && parent.name

          counters = counter_stack[idx + 1]
          "#{parent.name}[#{counters[parent.name]}]"
        end.compact
        path_parts << "#{node.name}[#{position}]"

        @cache[node.object_id] = "/#{path_parts.join('/')}"
      end
    end

    def compute_and_cache_path(node)
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
