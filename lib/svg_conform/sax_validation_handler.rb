# frozen_string_literal: true

require "nokogiri"
require_relative "element_proxy"
require_relative "validation_context"
require_relative "validation/error_tracker"
require_relative "validation/structural_invalidity_tracker"
require_relative "validation/node_id_manager"
require_relative "validation_result"
require_relative "references"

module SvgConform
  # SAX event handler for streaming SVG validation
  # Processes XML events and dispatches to requirements
  class SaxValidationHandler < Nokogiri::XML::SAX::Document
    attr_reader :result, :context

    # Class-level cache for requirement classifications by profile class
    @classification_cache = {}
    @classification_cache_mutex = Mutex.new

    class << self
      attr_reader :classification_cache, :classification_cache_mutex
    end

    def initialize(profile)
      @profile = profile
      @element_stack = [] # Track parent-child hierarchy
      @path_stack = [] # Current element path
      @position_counters = [] # Stack of sibling counters per level
      @parse_errors = []
      @result = nil # Will be set in end_document

      # Create validation context (without document reference for SAX)
      @context = create_sax_context

      # Classify requirements into immediate vs deferred (use cache if available)
      @immediate_requirements, @deferred_requirements = classify_requirements_with_cache
    end

    # SAX Event: Document start
    def start_document
      # Reset state in requirements that maintain state across validations
      reset_stateful_requirements

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
      # Create context using TrackerFactory for cleaner initialization
      trackers = Validation::TrackerFactory.create_all_trackers(nil)

      context = ValidationContext.allocate
      context.instance_variable_set(:@document, nil)
      context.instance_variable_set(:@profile, @profile)
      context.instance_variable_set(:@error_tracker, trackers[:error_tracker])
      context.instance_variable_set(:@node_id_manager,
                                    trackers[:node_id_manager])
      context.instance_variable_set(:@structural_invalidity_tracker,
                                    trackers[:structural_invalidity_tracker])
      context.instance_variable_set(:@reference_manifest,
                                    trackers[:reference_manifest])
      context.instance_variable_set(:@fixes, [])
      context.instance_variable_set(:@data, {})
      context
    end

    # Classify requirements based on validation needs (with caching)
    def classify_requirements_with_cache
      profile_key = @profile.class.name
      profile_requirements = @profile.requirements

      # Check cache first (thread-safe)
      @immediate_requirements = []
      @deferred_requirements = []

      classified = self.class.classification_cache_mutex.synchronize do
        self.class.classification_cache[profile_key]
      end

      if classified
        @immediate_requirements = classified[:immediate].map do |req_class|
          # Find the actual instance from profile requirements
          profile_requirements.find { |r| r.is_a?(req_class) }
        end.compact
        @deferred_requirements = classified[:deferred].map do |req_class|
          profile_requirements.find { |r| r.is_a?(req_class) }
        end.compact
      else
        # Classify and cache
        immediate_classes = []
        deferred_classes = []

        profile_requirements.each do |req|
          if req.respond_to?(:needs_deferred_validation?) && req.needs_deferred_validation?
            deferred_classes << req.class
          else
            immediate_classes << req.class
          end
        end

        # Store in cache
        self.class.classification_cache_mutex.synchronize do
          self.class.classification_cache[profile_key] = {
            immediate: immediate_classes,
            deferred: deferred_classes,
          }
        end

        @immediate_requirements = profile_requirements.select do |req|
          immediate_classes.include?(req.class)
        end
        @deferred_requirements = profile_requirements.select do |req|
          deferred_classes.include?(req.class)
        end
      end

      [@immediate_requirements, @deferred_requirements]
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

    # Reset state in requirements that maintain state
    def reset_stateful_requirements
      return unless @profile&.requirements

      @profile.requirements.each do |req|
        req.reset_state if req.respond_to?(:reset_state)
      end
    end
  end
end
