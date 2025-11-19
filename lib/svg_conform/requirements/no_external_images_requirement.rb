# frozen_string_literal: true

require_relative "base_requirement"

module SvgConform
  module Requirements
    # Validates that no external image references are present
    # All images must be embedded in the SVG
    class NoExternalImagesRequirement < BaseRequirement
      attribute :type, :string, default: -> { "NoExternalImagesRequirement" }
      attribute :check_image_elements, :boolean, default: true
      attribute :check_style_images, :boolean, default: true

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "type", to: :type
        map "check_image_elements", to: :check_image_elements
        map "check_style_images", to: :check_style_images
      end

      def check(node, context)
        return unless element?(node)

        case node.name
        when "image"
          check_image_element(node, context) if check_image_elements
        else
          check_style_attribute(node, context) if check_style_images
        end
      end

      def should_check_node?(node, context = nil)
        return false unless element?(node)
        return false if context&.node_structurally_invalid?(node)

        node.name == "image" || has_style_attribute?(node)
      end

      def validate_sax_element(element, context)
        case element.name
        when "image"
          check_image_element_sax(element, context) if check_image_elements
        else
          check_style_attribute_sax(element, context) if check_style_images
        end
      end

      private

      def check_image_element(node, context)
        # Check href and xlink:href attributes
        href = get_attribute(node, "href") || get_attribute(node, "xlink:href")
        return unless href && !embedded_image?(href)

        context.add_error(
          requirement_id: id,
          message: "External image reference not allowed: #{href}. Images must be embedded as data URIs.",
          node: node,
          severity: :error,
        )
      end

      def check_style_attribute(node, context)
        style_value = get_attribute(node, "style")
        return unless style_value

        # Check for url() references to images in background, background-image, etc.
        style_value.scan(/url\s*\(\s*['"]?([^'")\s]+)['"]?\s*\)/i) do
          url = ::Regexp.last_match(1)
          next if embedded_image?(url)

          context.add_error(
            requirement_id: id,
            message: "External image URL in style attribute not allowed: #{url}. Images must be embedded as data URIs.",
            node: node,
            severity: :error,
          )
        end
      end

      def check_image_element_sax(element, context)
        # Check href and xlink:href attributes
        href = element.raw_attributes["href"] || element.raw_attributes["xlink:href"]
        return unless href && !embedded_image?(href)

        context.add_error(
          requirement_id: id,
          message: "External image reference not allowed: #{href}. Images must be embedded as data URIs.",
          node: element,
          severity: :error,
        )
      end

      def check_style_attribute_sax(element, context)
        style_value = element.raw_attributes["style"]
        return unless style_value

        # Check for url() references to images in background, background-image, etc.
        style_value.scan(/url\s*\(\s*['"]?([^'")\s]+)['"]?\s*\)/i) do
          url = ::Regexp.last_match(1)
          next if embedded_image?(url)

          context.add_error(
            requirement_id: id,
            message: "External image URL in style attribute not allowed: #{url}. Images must be embedded as data URIs.",
            node: element,
            severity: :error,
          )
        end
      end

      def has_style_attribute?(node)
        !get_attribute(node, "style").nil?
      end

      def embedded_image?(url)
        return true if url.nil? || url.empty?

        # Data URLs are embedded
        return true if url.start_with?("data:")

        # Fragment identifiers (internal references) are allowed
        return true if url.start_with?("#")

        # Everything else is external
        false
      end
    end
  end
end
