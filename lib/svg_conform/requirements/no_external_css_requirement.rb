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
          check_style_element_sax(element, context) if check_style_elements
        when "link"
          check_link_element_sax(element, context) if check_link_elements
        else
          check_style_attribute_sax(element, context) if check_style_attributes
        end
      end

      private

      def check_style_element(node, context)
        # Check for @import rules in style elements
        content = node.text || ""

        if content =~ /@import\s+url\s*\(\s*['"]?([^'")\s]+)['"]?\s*\)/i
          url = ::Regexp.last_match(1)
          unless allowed_url?(url)
            context.add_error(
              requirement_id: id,
              message: "External CSS import not allowed: #{url}",
              node: node,
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
          node: node,
          severity: :error,
        )
      end

      def check_link_element(node, context)
        rel = get_attribute(node, "rel")
        href = get_attribute(node, "href")

        return unless rel&.downcase == "stylesheet" && href

        return if allowed_url?(href)

        context.add_error(
          requirement_id: id,
          message: "External CSS link not allowed: #{href}",
          node: node,
          severity: :error,
        )
      end

      def check_style_attribute(node, context)
        style_value = get_attribute(node, "style")
        return unless style_value

        # Check for url() references in style attributes
        return unless style_value =~ /url\s*\(\s*['"]?([^'")\s]+)['"]?\s*\)/i

        url = ::Regexp.last_match(1)
        return if allowed_url?(url)

        context.add_error(
          requirement_id: id,
          message: "External URL reference in style attribute not allowed: #{url}",
          node: node,
          severity: :error,
        )
      end

      def check_style_element_sax(element, context)
        # Check for @import rules in style elements
        content = element.text_content

        if content =~ /@import\s+url\s*\(\s*['"]?([^'")\s]+)['"]?\s*\)/i
          url = ::Regexp.last_match(1)
          unless allowed_url?(url)
            context.add_error(
              requirement_id: id,
              message: "External CSS import not allowed: #{url}",
              node: element,
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
          node: element,
          severity: :error,
        )
      end

      def check_link_element_sax(element, context)
        rel = element.raw_attributes["rel"]
        href = element.raw_attributes["href"]

        return unless rel&.downcase == "stylesheet" && href

        return if allowed_url?(href)

        context.add_error(
          requirement_id: id,
          message: "External CSS link not allowed: #{href}",
          node: element,
          severity: :error,
        )
      end

      def check_style_attribute_sax(element, context)
        style_value = element.raw_attributes["style"]
        return unless style_value

        # Check for url() references in style attributes
        return unless style_value =~ /url\s*\(\s*['"]?([^'")\s]+)['"]?\s*\)/i

        url = ::Regexp.last_match(1)
        return if allowed_url?(url)

        context.add_error(
          requirement_id: id,
          message: "External URL reference in style attribute not allowed: #{url}",
          node: element,
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
