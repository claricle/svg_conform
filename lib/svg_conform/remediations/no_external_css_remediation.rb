# frozen_string_literal: true

require_relative "base_remediation"

module SvgConform
  module Remediations
    # Remediation action to remove external CSS references
    class NoExternalCssRemediation < BaseRemediation
      attribute :type, :string, default: -> { "NoExternalCssRemediation" }
      attribute :strategy, :string, default: "remove_external_references"
      attribute :preserve_inline_styles, :boolean, default: true
      attribute :log_removed_elements, :boolean, default: true

      def apply(document, context)
        changes = []

        case @strategy
        when "remove_external_references"
          changes += remove_external_link_elements(document, context)
          changes += remove_external_imports_from_style_elements(document,
                                                                 context)
          changes += remove_external_urls_from_style_attributes(document,
                                                                context)
        else
          context.add_error(
            message: "Unknown remediation strategy: #{@strategy}",
            node: document.root,
          )
          return []
        end

        if @log_removed_elements && changes.any?
          log_remediation(context,
                          "Removed #{changes.length} external CSS references")
        end

        changes
      end

      private

      def remove_external_link_elements(document, context)
        changes = []

        document.traverse do |node|
          next unless element?(node) && node.name == "link"

          rel = get_attribute(node, "rel")
          href = get_attribute(node, "href")

          if rel&.downcase == "stylesheet" && href && !allowed_url?(href)
            if @log_removed_elements
              log_removal(context,
                          "Removing external CSS link: #{href}")
            end
            node.remove
            changes << {
              type: :element_removed,
              description: "Removed external CSS link: #{href}",
              node_name: node.name,
              href: href,
            }
          end
        end

        changes
      end

      def remove_external_imports_from_style_elements(document, context)
        changes = []

        document.traverse do |node|
          next unless element?(node) && node.name == "style"

          content = node.text || ""
          original_content = content.dup

          # Remove @import url() statements (including the newline)
          content.gsub!(/@import\s+url\s*\(\s*['"]?([^'")\s]+)['"]?\s*\)\s*;?\s*\n?/i) do |match|
            url = ::Regexp.last_match(1)
            if allowed_url?(url)
              match # Keep allowed URLs
            else
              if @log_removed_elements
                log_removal(context,
                            "Removing external CSS import: #{url}")
              end
              changes << {
                type: :content_modified,
                description: "Removed external CSS import: #{url}",
                node_name: node.name,
                url: url,
              }
              "" # Remove disallowed URLs
            end
          end

          # Remove @import "url" statements (including the newline)
          content.gsub!(/@import\s+['"]([^'"]+)['"]\s*;?\s*\n?/i) do |match|
            url = ::Regexp.last_match(1)
            if allowed_url?(url)
              match # Keep allowed URLs
            else
              if @log_removed_elements
                log_removal(context,
                            "Removing external CSS import: #{url}")
              end
              changes << {
                type: :content_modified,
                description: "Removed external CSS import: #{url}",
                node_name: node.name,
                url: url,
              }
              "" # Remove disallowed URLs
            end
          end

          # Update the node content if it changed
          if content != original_content
            # Clear existing text content and set new content
            node.text = content
          end
        end

        changes
      end

      def remove_external_urls_from_style_attributes(document, context)
        changes = []

        document.traverse do |node|
          next unless element?(node)

          style_value = get_attribute(node, "style")
          next unless style_value

          original_style = style_value.dup

          # Remove url() references in style attributes
          style_value.gsub!(/url\s*\(\s*['"]?([^'")\s]+)['"]?\s*\)/i) do |match|
            url = ::Regexp.last_match(1)
            if allowed_url?(url)
              match # Keep allowed URLs
            else
              if @log_removed_elements
                log_removal(context,
                            "Removing external URL from style attribute: #{url}")
              end
              changes << {
                type: :attribute_modified,
                description: "Removed external URL from style attribute: #{url}",
                node_name: node.name,
                attribute_name: "style",
                url: url,
              }
              "" # Remove disallowed URLs
            end
          end

          # Update the attribute if it changed
          if style_value != original_style
            set_attribute(node, "style",
                          style_value)
          end
        end

        changes
      end

      def allowed_url?(url)
        return true if url.nil? || url.empty?

        # Data URLs are typically allowed
        return true if url.start_with?("data:")

        # Fragment identifiers (internal references) are allowed
        return true if url.start_with?("#")

        # For remediation, we're more restrictive - only allow data: and fragment URLs
        false
      end

      def log_removal(context, message)
        context.add_info(message: message) if context.respond_to?(:add_info)
      end

      def log_remediation(context, message)
        context.add_info(message: message) if context.respond_to?(:add_info)
      end
    end
  end
end
