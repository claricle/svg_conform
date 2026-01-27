# frozen_string_literal: true

require_relative "base_requirement"

module SvgConform
  module Requirements
    # Validates that no external CSS references are present
    class NoExternalCssRequirement < BaseRequirement
      attribute :type, :string, default: -> { "NoExternalCssRequirement" }
      attribute :check_style_elements, :boolean, default: true
      attribute :check_style_attributes, :boolean, default: true
      attribute :check_link_elements, :boolean, default: true
      attribute :allowed_protocols, :string, collection: true

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "type", to: :type
        map "check_style_elements", to: :check_style_elements
        map "check_style_attributes", to: :check_style_attributes
        map "check_link_elements", to: :check_link_elements
        map "allowed_protocols", to: :allowed_protocols
      end

      class State
        attr_accessor :collected_styles

        def initialize
          @collected_styles = []
        end
      end

      def initialize(*args)
        super
        # No instance state - validation state stored in context
      end

      def check(node, context)
        return unless element?(node)

        case node.name
        when "style"
          check_style_element(node, context) if check_style_elements
        when "link"
          check_link_element(node, context) if check_link_elements
        else
          check_style_attribute(node, context) if check_style_attributes
        end
      end

      def needs_deferred_validation?
        check_style_elements # Only deferred if checking style elements
      end

      def collect_sax_data(element, context)
        state = context.state_for(self)
        # Collect style elements for deferred validation (text content needs to be complete)
        if check_style_elements && element.name == "style"
          state.collected_styles << element
        end
      end

      def validate_sax_complete(context)
        state = context.state_for(self)
        collected_style_elements = state.collected_styles
        return unless collected_style_elements

        # Validate collected style elements
        collected_style_elements.each do |element|
          check_style_element(element, context)
        end
      end

      def should_check_node?(node, context = nil)
        return false unless element?(node)
        return false if context&.node_structurally_invalid?(node)

        node.name == "style" ||
          node.name == "link" ||
          has_style_attribute?(node)
      end

      def validate_sax_element(element, context)
        case element.name
        when "style"
          # Style elements handled in deferred validation (need text content)
          # Already collected in collect_sax_data
        when "link"
          check_link_element(element, context) if check_link_elements
        else
          check_style_attribute(element, context) if check_style_attributes
        end
      end

      private

      def check_style_element(node_or_element, context)
        # Check for @import rules in style elements
        # Handle both DOM nodes (node.text) and SAX elements (element.text_content)
        content = if node_or_element.respond_to?(:text_content)
                    node_or_element.text_content
                  else
                    node_or_element.text || ""
                  end

        if content =~ /@import\s+url\s*\(\s*['"]?([^'")\s]+)['"]?\s*\)/i
          url = ::Regexp.last_match(1)
          unless allowed_url?(url)
            context.add_error(
              requirement_id: id,
              message: "External CSS import not allowed: #{url}",
              node: node_or_element,
              severity: :error,
            )
          end
        end

        return unless content =~ /@import\s+['"]([^'"]+)['"]/i

        url = ::Regexp.last_match(1)
        return if allowed_url?(url)

        context.add_error(
          requirement_id: id,
          message: "External CSS import not allowed: #{url}",
          node: node_or_element,
          severity: :error,
        )
      end

      def check_link_element(node_or_element, context)
        rel = get_attribute(node_or_element, "rel")
        href = get_attribute(node_or_element, "href")

        return unless rel&.downcase == "stylesheet" && href

        return if allowed_url?(href)

        context.add_error(
          requirement_id: id,
          message: "External CSS link not allowed: #{href}",
          node: node_or_element,
          severity: :error,
        )
      end

      def check_style_attribute(node_or_element, context)
        style_value = get_attribute(node_or_element, "style")
        return unless style_value

        # Check for url() references in style attributes
        return unless style_value =~ /url\s*\(\s*['"]?([^'")\s]+)['"]?\s*\)/i

        url = ::Regexp.last_match(1)
        return if allowed_url?(url)

        context.add_error(
          requirement_id: id,
          message: "External URL reference in style attribute not allowed: #{url}",
          node: node_or_element,
          severity: :error,
        )
      end

      def has_style_attribute?(node)
        !get_attribute(node, "style").nil?
      end

      def allowed_url?(url)
        return true if url.nil? || url.empty?

        # Data URLs are typically allowed
        return true if url.start_with?("data:")

        # Fragment identifiers (internal references) are allowed
        return true if url.start_with?("#")

        # Check against allowed protocols
        return false if allowed_protocols.nil? || allowed_protocols.empty?

        allowed_protocols.any? { |protocol| url.start_with?("#{protocol}:") }
      end
    end
  end
end
