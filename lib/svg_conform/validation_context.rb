# frozen_string_literal: true

require "set"

module SvgConform
  # Context object passed to rules during validation
  class ValidationContext
    attr_reader :document, :profile, :errors, :warnings, :fixes,
                :validity_errors

    def initialize(document, profile)
      @document = document
      @profile = profile
      @errors = []
      @warnings = []
      @validity_errors = []
      @infos = []
      @data = {}
      @structurally_invalid_node_ids = Set.new
      @node_id_cache = {}
      @cache_populated = false
    end

    # Mark a node as structurally invalid (e.g., invalid parent-child relationship)
    # Other requirements should skip attribute validation on these nodes
    # Also marks all descendants as invalid since they'll be removed with the parent
    def mark_node_structurally_invalid(node)
      node_id = generate_node_id(node)
      return if node_id.nil?  # Safety check

      @structurally_invalid_node_ids.add(node_id)

      # Mark all descendants as invalid too
      mark_descendants_invalid(node)
    end

    # Mark all descendants of a node as structurally invalid
    def mark_descendants_invalid(node)
      return unless node.respond_to?(:children)

      node.children.each do |child|
        child_id = generate_node_id(child)
        return if child_id.nil?  # Safety check

        @structurally_invalid_node_ids.add(child_id)
        # Recursively mark descendants
        mark_descendants_invalid(child)
      end
    end

    # Check if a node is structurally invalid
    def node_structurally_invalid?(node)
      node_id = generate_node_id(node)
      return false if node_id.nil?  # Safety check

      @structurally_invalid_node_ids.include?(node_id)
    end

    def add_error(node:, message:, rule: nil, requirement: nil,
requirement_id: nil, severity: nil, fix: nil, data: {})
      # Support both old rule system and new requirements system
      rule_or_requirement = requirement || rule

      error = ValidationIssue.new(
        type: :error,
        rule: rule_or_requirement,
        node: node,
        message: message,
        fix: fix,
        data: data,
        requirement_id: requirement_id,
        severity: severity,
      )

      # Handle special severity types
      if severity == :validity_error
        @validity_errors << error
      else
        @errors << error
      end

      error
    end

    def add_warning(rule:, node:, message:, fix: nil)
      warning = ValidationIssue.new(
        type: :warning,
        rule: rule,
        node: node,
        message: message,
        fix: fix,
      )
      @warnings << warning
      warning
    end

    def add_fix(fix)
      @fixes << fix
    end

    def has_errors?
      !@errors.empty?
    end

    def has_warnings?
      !@warnings.empty?
    end

    def has_fixes?
      !@fixes.empty?
    end

    def issue_count
      @errors.size + @warnings.size
    end

    def fixable_count
      (@errors + @warnings).count(&:fixable?)
    end

    def set_data(key, value)
      @data[key] = value
    end

    def get_data(key)
      @data[key]
    end

    # Generate a unique identifier for a node based on its path
    # Builds a stable path by walking up the parent chain
    # OPTIMIZED: Lazy cache population - populate entire cache on first call
    def generate_node_id(node)
      return nil unless node.respond_to?(:name)

      # Populate cache for ALL nodes on first access
      unless @cache_populated
        populate_node_id_cache
        @cache_populated = true
      end

      # Try cache lookup first
      cached_id = @node_id_cache[node]
      return cached_id if cached_id

      # Fall back to building path if node not in cache
      # (happens when different traversals create different wrapper objects)
      build_node_path(node)
    end

    private

    # Populate cache for all nodes using document.traverse with parent tracking
    def populate_node_id_cache
      parent_stack = []
      counter_stack = [{}]  # Stack of {element_name => count} hashes

      @document.traverse do |node|
        next unless node.respond_to?(:name) && node.name

        # Detect parent changes by checking node.parent
        current_parent = node.respond_to?(:parent) ? node.parent : nil

        # Adjust stack based on actual parent
        while parent_stack.size > 0 && !parent_stack.last.equal?(current_parent)
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
        @node_id_cache[node] = build_node_path(node)
      end
    end

    # Traverse tree, building paths with forward position counters
    def traverse_with_forward_counting(node, path_parts, sibling_counters)
      return unless node.respond_to?(:name) && node.name

      # Increment counter for this node name at current level
     sibling_counters[node.name] ||= 0
      sibling_counters[node.name] += 1
      position = sibling_counters[node.name]

      # Build and cache path
      current_path = path_parts + ["#{node.name}[#{position}]"]
      @node_id_cache[node] = "/#{current_path.join('/')}"

      # Traverse children with fresh counters
      if node.respond_to?(:children)
        child_counters = {}
        node.children.each do |child|
          traverse_with_forward_counting(child, current_path, child_counters)
        end
      end
    end

    # Build path-based ID for a node (original logic, unchanged)
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

  # Base class for validation issues
  class ValidationIssue
    attr_reader :type, :rule, :node, :message, :fix, :data,
                :requirement_id_override, :severity

    def initialize(type:, rule:, node:, message:, fix: nil, data: {},
requirement_id: nil, severity: nil, violation_type: nil)
      @type = type
      @rule = rule
      @node = node
      @message = message
      @fix = fix
      @data = data
      @requirement_id_override = requirement_id
      @severity = severity
      @violation_type = violation_type || detect_violation_type
    end

    def requirement_id
      return @requirement_id_override.to_s if @requirement_id_override

      if @rule.respond_to?(:id)
        @rule.id.to_s
      elsif @rule.respond_to?(:class) && @rule.class.respond_to?(:name)
        # Extract ID from class name for requirements
        class_name = @rule.class.name.split("::").last
        class_name.gsub(/Requirement$/, "").downcase.gsub(/([a-z])([A-Z])/,
                                                          '\1_\2').downcase
      else
        "unknown"
      end
    end

    def error?
      @type == :error
    end

    def warning?
      @type == :warning
    end

    def fixable?
      !@fix.nil?
    end

    def line
      @node.respond_to?(:line) ? @node.line : nil
    end

    def column
      @node.respond_to?(:column) ? @node.column : nil
    end

    def element_name
      @node.respond_to?(:name) ? @node.name : nil
    end

    def apply_fix
      return false unless fixable?

      begin
        if @fix.respond_to?(:call)
          @fix.call
        else
          @fix.apply
        end
        true
      rescue StandardError
        false
      end
    end

    def to_h
      {
        type: @type,
        rule: rule_id,
        message: @message,
        line: line,
        column: column,
        element: element_name,
        fixable: fixable?,
      }
    end

    def violation_type
      @violation_type
    end

    def remediable?
      case @violation_type
      when :color_violation, :font_violation, :content_violation, :reference_violation,
           :namespace_violation, :viewbox_violation, :style_violation
        true
      when :structural_violation
        false
      else
        # Default to remediable for backward compatibility
        true
      end
    end

    def remediation_type
      case @violation_type
      when :color_violation, :font_violation
        :convert
      when :content_violation, :reference_violation, :namespace_violation
        :remove
      when :viewbox_violation
        :add
      when :style_violation
        :promote
      else
        :unknown
      end
    end

    def remediation_confidence
      case @violation_type
      when :color_violation, :font_violation, :style_violation
        :automatic
      when :viewbox_violation, :namespace_violation
        :safe_structural
      when :content_violation, :reference_violation
        :safe_removal
      else
        :manual_review
      end
    end

    def suggested_action
      case @violation_type
      when :color_violation
        "Convert color to allowed equivalent using CssColor"
      when :font_violation
        "Map font family to generic equivalent"
      when :content_violation
        "Remove forbidden element or attribute"
      when :reference_violation
        "Remove broken reference or containing element"
      when :namespace_violation
        "Fix namespace declarations and remove invalid elements/attributes"
      when :viewbox_violation
        "Add missing viewBox attribute"
      when :style_violation
        "Promote style properties to attributes"
      when :structural_violation
        "Manual fix required - document structure issue"
      else
        "Apply available remediation"
      end
    end

    def affects_content?
      case @violation_type
      when :content_violation, :reference_violation
        true
      when :color_violation, :font_violation, :style_violation, :viewbox_violation, :namespace_violation
        false
      else
        false
      end
    end

    def to_s
      location = line ? " at line #{line}" : ""
      location += ":#{column}" if column
      rule_info = rule_id ? " (#{rule_id})" : ""
      remediation_info = remediable? ? " [#{remediation_type}]" : " [NOT REMEDIABLE]"
      "#{@message}#{location}#{rule_info}#{remediation_info}"
    end

    def to_h
      {
        type: @type,
        rule: rule_id,
        message: @message,
        line: line,
        column: column,
        element: element_name,
        fixable: fixable?,
        remediable: remediable?,
        violation_type: @violation_type,
        remediation_type: remediation_type,
        remediation_confidence: remediation_confidence,
        suggested_action: suggested_action,
        affects_content: affects_content?,
      }
    end

    private

    def detect_violation_type
      req_id = requirement_id.downcase
      msg = @message.downcase

      # First check for structural violations (non-remediable)
      return :structural_violation if msg.include?("root element must be") ||
        msg.include?("malformed") ||
        msg.include?("invalid document") ||
        msg.include?("required element missing") ||
        msg.include?("invalid hierarchy")

      # Then check requirement-based violations (remediable)
      case req_id
      when /color/
        :color_violation
      when /font/
        :font_violation
      when /forbidden|content/
        :content_violation
      when /reference|id/
        :reference_violation
      when /namespace/
        :namespace_violation
      when /viewbox/
        :viewbox_violation
      when /style/
        :style_violation
      else
        # Check message content for clues
        return :color_violation if msg.include?("color")
        return :font_violation if msg.include?("font")
        return :content_violation if msg.include?("forbidden")
        return :reference_violation if msg.include?("reference") || msg.include?("href")
        return :namespace_violation if msg.include?("namespace")
        return :viewbox_violation if msg.include?("viewbox")
        return :style_violation if msg.include?("style")

        :unknown_violation
      end
    end

    def rule_id
      return @requirement_id_override if @requirement_id_override
      return @rule.id if @rule.respond_to?(:id)

      if @rule.respond_to?(:class) && @rule.class.respond_to?(:name)
        # Extract ID from class name for requirements
        class_name = @rule.class.name.split("::").last
        class_name.gsub(/Requirement$/, "").downcase.gsub(/([a-z])([A-Z])/,
                                                          '\1_\2').downcase
      else
        "unknown"
      end
    end
  end
end
