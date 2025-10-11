# frozen_string_literal: true

require_relative "base_remediation"

module SvgConform
  module Remediations
    # Remediation for embedding external fonts
    # NOTE: This is a placeholder - actual font embedding would require
    # fetching external fonts and converting them to data URIs
    class FontEmbeddingRemediation < BaseRemediation
      attribute :type, :string, default: -> { "FontEmbeddingRemediation" }

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "type", to: :type
        map "targets", to: :targets
      end

      def apply(document, _context)
        changes = []

        # Find all style elements with @font-face rules
        document.xpath("//style").each do |style_node|
          content = style_node.text || ""
          next unless content.include?("@font-face")

          modified_content = embed_fonts_in_css(content, changes)
          if modified_content != content
            style_node.content = modified_content
          end
        end

        # Find font-face elements with external references
        document.xpath("//font-face-src/font-face-uri").each do |uri_node|
          href = get_attribute(uri_node,
                               "xlink:href") || get_attribute(uri_node, "href")
          next unless href && !href.start_with?("data:", "#")

          # Convert external font to data URI
          embedded_uri = fetch_and_embed_font(href)
          if embedded_uri
            set_attribute(uri_node, "xlink:href", embedded_uri)
            changes << {
              type: "font_embedded",
              element: "font-face-uri",
              message: "Embedded external font: #{href}",
            }
          else
            changes << {
              type: "font_embedding_failed",
              element: "font-face-uri",
              message: "Failed to embed font: #{href}",
            }
          end
        end

        changes
      end

      def can_remediate?
        true
      end

      private

      def embed_fonts_in_css(css_content, changes)
        # Match @font-face blocks and replace external URLs with data URIs
        css_content.gsub(/@font-face\s*\{([^}]+)\}/m) do |_font_face_block|
          font_face_content = ::Regexp.last_match(1)

          # Find src: url(...) declarations
          modified_content = font_face_content.gsub(/src\s*:\s*url\s*\(\s*['"]?([^'")\s]+)['"]?\s*\)/i) do |url_match|
            url = ::Regexp.last_match(1)

            # Skip if already embedded or internal reference
            next url_match if url.start_with?("data:", "#")

            # Fetch and embed the font
            embedded_uri = fetch_and_embed_font(url)
            if embedded_uri
              changes << {
                type: "font_embedded",
                element: "style",
                message: "Embedded external font: #{url}",
              }
              "src: url(#{embedded_uri})"
            else
              changes << {
                type: "font_embedding_failed",
                element: "style",
                message: "Failed to embed font: #{url}",
              }
              url_match
            end
          end

          "@font-face {#{modified_content}}"
        end
      end

      def fetch_and_embed_font(url)
        require "net/http"
        require "uri"
        require "base64"

        # Parse URL
        uri = URI.parse(url)

        # Fetch the font
        response = Net::HTTP.get_response(uri)
        return nil unless response.is_a?(Net::HTTPSuccess)

        # Get content type or infer from URL
        content_type = response["content-type"] || infer_font_mime_type(url)

        # Encode as base64
        base64_data = Base64.strict_encode64(response.body)

        # Return data URI
        "data:#{content_type};base64,#{base64_data}"
      rescue StandardError => e
        warn "Failed to fetch font #{url}: #{e.message}"
        nil
      end

      def infer_font_mime_type(url)
        case url.downcase
        when /\.woff2$/
          "font/woff2"
        when /\.woff$/
          "font/woff"
        when /\.ttf$/
          "font/ttf"
        when /\.otf$/
          "font/otf"
        when /\.eot$/
          "application/vnd.ms-fontobject"
        else
          "font/woff2" # Default to woff2
        end
      end
    end
  end
end
