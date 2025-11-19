# frozen_string_literal: true

require "nokogiri"
require_relative "element_proxy"
require_relative "validation_context"
require_relative "validation_result"
require_relative "references"

module SvgConform
  # SAX event handler for streaming SVG validation
  # Processes XML events and dispatches to requirements
  class SaxValidationHandler < Nokogiri::XML::SAX::Document
    attr_reader :result, :context

    def initialize(profile)
      @profile = profile
      @element_stack = [] # Track parent-child hierarchy
      @path_stack = [] # Current element path
      @position_counters = [] # Stack of sibling counters per level
      @parse_errors = []
      @result = nil # Will be set in end_document

      # Create validation context (without document reference for SAX)
      @context = create_sax_context

      # Classify requirements into immediate vs deferred
      @immediate_requirements = []
      @deferred_requirements = []
      classify_requirements
    end

    # SAX Event: Document start
    def start_document
      # Initialize root level counters
      @position_counters.push({})
    end

    # SAX Event: Element start tag
    def start_element(name, attributes = [])
      attrs = Hash[attributes]

      # Calculate position among siblings at current level
      current_counters = @position_counters.last || {}
      current_counters[name] ||= 0
      current_counters[name] += 1
      position = current_counters[name]

      # Build element proxy
      element = ElementProxy.new(
        name: name,
        attributes: attrs,
        position: position,
        path: @path_stack.dup,
        parent: @element_stack.last,
      )

      # Push to stacks
      @element_stack.push(element)
      @path_stack.push("#{name}[#{position}]")
      @position_counters.push({}) # New level for this element's children

      # Validate with immediate requirements
      @immediate_requirements.each do |req|
        req.validate_sax_element(element, @context)
      end

      # Deferred requirements may need to collect data
      @deferred_requirements.each do |req|
        if req.respond_to?(:collect_sax_data)
          req.collect_sax_data(element,
                               @context)
        end
      end
    end

    # SAX Event: Element end tag
    def end_element(_name)
      @element_stack.pop
      @path_stack.pop
      @position_counters.pop
    end

    # SAX Event: Text content
    def characters(string)
      return if @element_stack.empty?

      @element_stack.last.text_content << string
    end

    # SAX Event: Document complete
    def end_document
      # Run deferred validation
      @deferred_requirements.each do |req|
        req.validate_sax_complete(@context)
      end

      # Create result
      @result = ValidationResult.new(nil, @profile, @context)
    end

    # SAX Event: Parse error
    def error(error_message)
      @parse_errors << error_message
    end

    # SAX Event: Warning
    def warning(warning_message)
      # Can log warnings if needed
    end

    # Handle parse errors
    def add_parse_error(error)
      @context.add_error(
        node: nil,
        message: "Parse error: #{error.message}",
        requirement_id: "parse_error",
        severity: :error,
      )
    end

    # Get result (will be nil until end_document called)
    def result
      @result || create_incomplete_result
    end

    private

    def create_incomplete_result
      # Return result even if parsing incomplete
      ValidationResult.new(nil, @profile, @context)
    end

    # Create a SAX-compatible validation context
    def create_sax_context
      # Create context without triggering DOM operations
      context = ValidationContext.allocate
      context.instance_variable_set(:@document, nil)
      context.instance_variable_set(:@profile, @profile)
      context.instance_variable_set(:@errors, [])
      context.instance_variable_set(:@warnings, [])
      context.instance_variable_set(:@validity_errors, [])
      context.instance_variable_set(:@infos, [])
      context.instance_variable_set(:@data, {})
      context.instance_variable_set(:@structurally_invalid_node_ids, Set.new)
      context.instance_variable_set(:@node_id_cache, {})
      context.instance_variable_set(:@cache_populated, true) # Skip population for SAX
      context.instance_variable_set(:@reference_manifest,
                                    References::ReferenceManifest.new(source_document: nil))
      context
    end

    # Classify requirements based on validation needs
    def classify_requirements
      return unless @profile&.requirements

      @profile.requirements.each do |req|
        if req.respond_to?(:needs_deferred_validation?) && req.needs_deferred_validation?
          @deferred_requirements << req
        else
          @immediate_requirements << req
        end
      end
    end
  end
end
