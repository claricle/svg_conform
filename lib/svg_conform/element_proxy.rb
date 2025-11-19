# frozen_string_literal: true

module SvgConform
  # Lightweight attribute representation for SAX parsing
  class SaxAttribute
    attr_reader :name, :value

    def initialize(name, value)
      @name = name
      @value = value
    end

    def namespace
      nil  # DOM handles namespaces via XPath; SAX checks attribute names directly
    end
  end

  # Lightweight element representation during SAX parsing
  # Provides a node-like interface for validation requirements
  # without the overhead of full DOM tree
  class ElementProxy
    attr_reader :name, :position, :path, :parent, :raw_attributes
    attr_accessor :text_content, :child_counters

    def initialize(name:, attributes:, position:, path:, parent:)
      @name = name
      @raw_attributes = attributes  # Hash of attribute name => value
      @position = position
      @path = path  # Array of parent path parts
      @parent = parent
      @text_content = String.new  # Mutable string
      @child_counters = {}  # Track child element positions
    end

    # Build full path ID for this element
    def path_id
      parts = @path + ["#{@name}[#{@position}]"]
      "/#{parts.join('/')}"
    end

    # Return attributes as array of SaxAttribute objects (for compatibility)
    def attributes
      @raw_attributes.map { |name, value| SaxAttribute.new(name, value) }
    end

    # Check if this element has a specific attribute
    def attribute(name)
      value = @raw_attributes[name] || @raw_attributes[name.to_s]
      value ? SaxAttribute.new(name, value) : nil
    end

    # Get attribute value (alias for compatibility)
    def [](name)
      @raw_attributes[name] || @raw_attributes[name.to_s]
    end

    # Check if attribute exists
    def has_attribute?(name)
      @raw_attributes.key?(name) || @raw_attributes.key?(name.to_s)
    end

    # Get namespace from attributes or parent
    def namespace
      @raw_attributes['xmlns'] || @parent&.namespace
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
      @raw_attributes.key?(method.to_s) || @raw_attributes.key?(method.to_sym) || super
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
