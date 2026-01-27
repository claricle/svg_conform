# frozen_string_literal: true

require "nokogiri"
require_relative "element_proxy"
require_relative "validation_context"
require_relative "validation/error_tracker"
require_relative "validation/structural_invalidity_tracker"
require_relative "validation/node_id_manager"
require_relative "validation_result"
require_relative "references"
require_relative "classification_cache"

module SvgConform
  # SAX event handler for streaming SVG validation
  # Processes XML events and dispatches to requirements
  #
  # == Requirement classification
  #
  # The handler classifies requirements into two categories:
  #
  # 1. Immediate validation requirements (14) - validate during parsing
  #    - These requirements implement +validate_sax_element+ and validate
  #      each element as it is encountered
  #    - No state is maintained between elements
  #
  # 2. Deferred validation requirements (3) - collect data, validate at end
  #    - These requirements implement +collect_sax_data+ and +validate_sax_complete+
  #    - State is stored in requirement-specific State classes via +context.state_for+
  #    - Validation happens after parsing is complete, when all data is available
  #
  # == State management
  #
  # Each handler instance has its own cache and fresh requirement instances,
  # ensuring no state leakage between validations.
  #
  # Profile reuse for multiple validations:
  # - Profile is created once with requirement instances (configuration from YAML)
  # - Each validation creates a fresh SaxValidationHandler with fresh ValidationContext
  # - ValidationContext creates fresh State instances for deferred requirements
  # - No state pollution occurs across validations
  class SaxValidationHandler < Nokogiri::XML::SAX::Document
    attr_reader :result, :context

    def initialize(profile)
      @profile = profile
      @element_stack = [] # Track parent-child hierarchy
      @path_stack = [] # Current element path
      @position_counters = [] # Stack of sibling counters per level
      @parse_errors = []
      @result = nil # Will be set in end_document

      # Create instance-level cache (no shared state between handlers)
      @classification_cache = ClassificationCache.new

      # Use profile requirements directly (config is stateless)
      # Validation state lives in context, not in requirements
      @requirements = @profile.requirements || []

      # Create validation context (without document reference for SAX)
      @context = create_sax_context

      # Classify requirements into immediate vs deferred (use instance cache)
      @immediate_requirements, @deferred_requirements = classify_requirements_with_cache
    end

    # SAX Event: Document start
    def start_document
      # No need to reset state - each validation has fresh requirement instances
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
      context.instance_variable_set(:@state_registry, {})
      context
    end

    # Classify requirements based on validation needs (with instance-level caching)
    def classify_requirements_with_cache
      profile_key = @profile.name || @profile.object_id.to_s

      # Use instance-level cache (no mutexes needed - per-handler isolation)
      @classification_cache.fetch(profile_key) do
        # Classify by requirement classes
        immediate_classes = []
        deferred_classes = []

        @requirements.each do |req|
          if req.respond_to?(:needs_deferred_validation?) && req.needs_deferred_validation?
            deferred_classes << req.class
          else
            immediate_classes << req.class
          end
        end

        # Cache the classification by class
        { immediate: immediate_classes, deferred: deferred_classes }
      end

      # Map back to actual requirement instances from @requirements
      classified = @classification_cache.fetch(profile_key) { {} }

      immediate = classified[:immediate].flat_map do |req_class|
        @requirements.select { |r| r.is_a?(req_class) }
      end

      deferred = classified[:deferred].flat_map do |req_class|
        @requirements.select { |r| r.is_a?(req_class) }
      end

      [immediate, deferred]
    end
  end
end
