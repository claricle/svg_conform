# frozen_string_literal: true

module SvgConform
  # Lightweight element representation during SAX parsing
  # Provides a node-like interface for validation requirements
  # without the overhead of full DOM tree
  class ElementProxy
    attr_reader :name, :attributes, :position, :path, :parent
    attr_accessor :text_content, :child_counters

    def initialize(name:, attributes:, position:, path:, parent:)
      @name = name
      @attributes = attributes
      @position = position
      @path = path  # Array of parent path parts
      @parent = parent
      @text_content = ""
      @child_counters = {}  # Track child element positions
    end

    # Build full path ID for this element
    def path_id
      parts = @path + ["#{@name}[#{@position}]"]
      "/#{parts.join('/')}"
    end

    # Check if this element has a specific attribute
    def attribute(name)
      @attributes[name]
    end

    # Get attribute value (alias for compatibility)
    def [](name)
      @attributes[name]
    end

    # Check if attribute exists
    def has_attribute?(name)
      @attributes.key?(name)
    end

    # Get namespace from attributes or parent
    def namespace
      @attributes['xmlns'] || @parent&.namespace
    end

    # Check if this is a text node (always false for ElementProxy)
    def text?
      false
    end

    # Support dynamic attribute access
    def method_missing(method, *args)
      if method.to_s.end_with?('?')
        # Boolean check
        has_attribute?(method.to_s.chomp('?'))
      else
        # Attribute access
        @attributes[method.to_s] || @attributes[method.to_sym]
      end
    end

    def respond_to_missing?(method, include_private = false)
      @attributes.key?(method.to_s) || @attributes.key?(method.to_sym) || super
    end

    # For compatibility with validation context
    def line
      nil  # SAX doesn't provide line numbers easily
    end

    def column
      nil
    end

    # Provide a stable identifier for this element
    def element_id
      path_id
    end
  end
end
