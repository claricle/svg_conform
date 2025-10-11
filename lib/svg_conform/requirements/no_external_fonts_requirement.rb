# frozen_string_literal: true

require_relative "base_requirement"

module SvgConform
  module Requirements
    # Validates that no external font references are present
    # All fonts must be embedded in the SVG
    class NoExternalFontsRequirement < BaseRequirement
      attribute :type, :string, default: -> { "NoExternalFontsRequirement" }
      attribute :check_font_face, :boolean, default: true
      attribute :check_style_fonts, :boolean, default: true

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "type", to: :type
        map "check_font_face", to: :check_font_face
        map "check_style_fonts", to: :check_style_fonts
      end

      def check(node, context)
        return unless element?(node)

        case node.name
        when "style"
          check_style_element(node, context) if check_style_fonts
        when "font-face"
          check_font_face_element(node, context) if check_font_face
        else
          check_style_attribute(node, context) if check_style_fonts
        end
      end

      def should_check_node?(node, context = nil)
        return false unless element?(node)
        return false if context&.node_structurally_invalid?(node)

        node.name == "style" ||
          node.name == "font-face" ||
          has_style_attribute?(node)
      end

      private

      def check_style_element(node, context)
        # Check for @font-face with external src in style elements
        content = node.text || ""

        # Match @font-face blocks
        content.scan(/@font-face\s*\{([^}]+)\}/m) do |match|
          font_face_content = match[0]

          # Check for src with url() that is not data: URI
          if font_face_content =~ /src\s*:\s*url\s*\(\s*['"]?([^'")\s]+)['"]?\s*\)/i
            url = ::Regexp.last_match(1)
            unless embedded_font?(url)
              context.add_error(
                requirement_id: id,
                message: "External font reference not allowed: #{url}. Fonts must be embedded as data URIs.",
                node: node,
                severity: :error,
              )
            end
          end
        end
      end

      def check_font_face_element(node, context)
        # Check font-face-src and font-face-uri elements
        node.xpath(".//font-face-src/font-face-uri").each do |uri_node|
          href = get_attribute(uri_node,
                               "xlink:href") || get_attribute(uri_node, "href")
          if href && !embedded_font?(href)
            context.add_error(
              requirement_id: id,
              message: "External font reference in font-face-uri not allowed: #{href}. Fonts must be embedded as data URIs.",
              node: uri_node,
              severity: :error,
            )
          end
        end
      end

      def check_style_attribute(node, context)
        style_value = get_attribute(node, "style")
        return unless style_value

        # Check for font-family with url() references
        return unless style_value =~ /font-family\s*:\s*.*url\s*\(\s*['"]?([^'")\s]+)['"]?\s*\)/i

        url = ::Regexp.last_match(1)
        return if embedded_font?(url)

        context.add_error(
          requirement_id: id,
          message: "External font URL in style attribute not allowed: #{url}. Fonts must be embedded as data URIs.",
          node: node,
          severity: :error,
        )
      end

      def has_style_attribute?(node)
        !get_attribute(node, "style").nil?
      end

      def embedded_font?(url)
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
