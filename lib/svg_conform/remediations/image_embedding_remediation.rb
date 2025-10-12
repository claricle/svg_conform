# frozen_string_literal: true

require_relative "base_remediation"

module SvgConform
  module Remediations
    # Remediation for embedding external images
    class ImageEmbeddingRemediation < BaseRemediation
      attribute :type, :string, default: -> { "ImageEmbeddingRemediation" }

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "type", to: :type
        map "targets", to: :targets
      end

      def apply(document, _context)
        changes = []

        # Find all image elements with external references
        document.xpath("//image").each do |image_node|
          href = get_attribute(image_node,
                               "href") || get_attribute(image_node,
                                                        "xlink:href")
          next unless href && !href.start_with?("data:", "#")

          # Convert external image to data URI
          embedded_uri = fetch_and_embed_image(href)
          if embedded_uri
            # Update both href variants for compatibility
            set_attribute(image_node, "href", embedded_uri)
            if get_attribute(
              image_node, "xlink:href"
            )
              set_attribute(image_node, "xlink:href",
                            embedded_uri)
            end

            changes << {
              type: "image_embedded",
              element: "image",
              message: "Embedded external image: #{href}",
            }
          else
            changes << {
              type: "image_embedding_failed",
              element: "image",
              message: "Failed to embed image: #{href}",
            }
          end
        end

        # Find style attributes with background images
        document.traverse do |node|
          next unless element?(node)

          style_value = get_attribute(node, "style")
          next unless style_value&.include?("url(")

          modified_style = embed_images_in_style(style_value, changes)
          if modified_style != style_value
            set_attribute(node, "style", modified_style)
          end
        end

        changes
      end

      def can_remediate?
        true
      end

      private

      def embed_images_in_style(style_value, changes)
        # SECURITY: Prevent ReDoS by limiting input length and using bounded quantifiers
        # GitHub CodeQL: Regular expression with excessive backtracking
        return style_value if style_value.length > 10_000

        # Replace url() references with data URIs
        # Use bounded quantifier {1,2000} to prevent exponential backtracking
        style_value.gsub(/url\s*\(\s*['"]?([^'")\s]{1,2000})['"]?\s*\)/i) do |url_match|
          url = ::Regexp.last_match(1)

          # Skip if already embedded or internal reference
          next url_match if url.start_with?("data:", "#")

          # Fetch and embed the image
          embedded_uri = fetch_and_embed_image(url)
          if embedded_uri
            changes << {
              type: "image_embedded",
              element: "style",
              message: "Embedded external image: #{url}",
            }
            "url(#{embedded_uri})"
          else
            changes << {
              type: "image_embedding_failed",
              element: "style",
              message: "Failed to embed image: #{url}",
            }
            url_match
          end
        end
      end

      def fetch_and_embed_image(url)
        require "net/http"
        require "uri"
        require "base64"

        # Parse URL
        uri = URI.parse(url)

        # Fetch the image
        response = Net::HTTP.get_response(uri)
        return nil unless response.is_a?(Net::HTTPSuccess)

        # Get content type or infer from URL
        content_type = response["content-type"] || infer_image_mime_type(url)

        # Encode as base64
        base64_data = Base64.strict_encode64(response.body)

        # Return data URI
        "data:#{content_type};base64,#{base64_data}"
      rescue StandardError => e
        warn "Failed to fetch image #{url}: #{e.message}"
        nil
      end

      def infer_image_mime_type(url)
        case url.downcase
        when /\.png$/
          "image/png"
        when /\.jpe?g$/
          "image/jpeg"
        when /\.gif$/
          "image/gif"
        when /\.svg$/
          "image/svg+xml"
        when /\.webp$/
          "image/webp"
        when /\.bmp$/
          "image/bmp"
        else
          "image/png" # Default to PNG
        end
      end
    end
  end
end
