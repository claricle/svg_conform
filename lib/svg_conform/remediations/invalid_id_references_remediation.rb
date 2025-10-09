# frozen_string_literal: true

require_relative "base_remediation"

module SvgConform
  module Remediations
    # Remediation action for fixing invalid ID references
    # Based on the Lucid SVG fix script behavior
    class InvalidIdReferencesRemediation < BaseRemediation
      attribute :type, :string, default: -> { "InvalidIdReferencesRemediation" }
      attribute :strategy, :string, default: "remove_invalid_use"
      attribute :log_removed_elements, :boolean, default: false
      attribute :create_placeholder_comment, :boolean, default: false
      attribute :preserve_valid_attributes, :boolean, default: true

      def apply(document, _context)
        changes = []

        # Find all use elements with invalid href references
        document.traverse do |node|
          next unless node.respond_to?(:name) && node.name == "use"

          href = get_attribute(node,
                               "href") || get_attribute(node, "xlink:href")
          next unless href&.start_with?("#")

          referenced_id = href[1..] # Remove the #
          next if document.xpath("//*[@id='#{referenced_id}']").any? # ID exists, skip

          # Handle invalid ID reference
          change = handle_use_element(node,
                                      { href: href, invalid_id: referenced_id })
          changes << change if change
        end

        changes
      end

      private

      def handle_use_element(node, data)
        case @strategy
        when "remove_invalid_use"
          remove_use_element(node, data)
        when "remove_invalid_href"
          remove_href_attribute(node, data)
        when "replace_with_placeholder"
          replace_with_placeholder(node, data)
        else
          raise "Unknown strategy: #{@strategy}"
        end
      end

      def handle_other_id_reference(node, data)
        case @strategy
        when "remove_invalid_use", "remove_invalid_href"
          remove_invalid_attribute(node, data)
        when "replace_with_placeholder"
          replace_attribute_with_placeholder(node, data)
        else
          raise "Unknown strategy: #{@strategy}"
        end
      end

      def remove_use_element(node, data)
        if @create_placeholder_comment
          comment_text = "Removed invalid use element: href=#{data[:href]}, invalid_id=#{data[:invalid_id]}"
          comment = create_comment(node.document, comment_text)
          replace_node(node, comment)
        else
          remove_node(node)
        end

        log_change(
          :remove_element,
          "Removed use element with invalid ID reference: #{data[:invalid_id]}",
          node,
        )
      end

      def remove_href_attribute(node, data)
        # Remove both possible href attributes
        remove_attribute(node, "xlink:href")
        remove_attribute(node, "href")

        log_change(
          :remove_attribute,
          "Removed invalid href attribute referencing: #{data[:invalid_id]}",
          node,
        )
      end

      def replace_with_placeholder(node, data)
        comment_text = "Invalid use element removed: #{node.to_xml.strip}"
        comment = create_comment(node.document, comment_text)
        replace_node(node, comment)

        log_change(
          :replace_with_comment,
          "Replaced use element with comment due to invalid ID reference: #{data[:invalid_id]}",
          node,
        )
      end

      def remove_invalid_attribute(node, data)
        attribute_name = data[:attribute]
        remove_attribute(node, attribute_name)

        log_change(
          :remove_attribute,
          "Removed #{attribute_name} attribute with invalid ID reference: #{data[:invalid_id]}",
          node,
        )
      end

      def replace_attribute_with_placeholder(node, data)
        attribute_name = data[:attribute]
        placeholder_value = "none" # Safe fallback value
        set_attribute(node, attribute_name, placeholder_value)

        log_change(
          :replace_attribute,
          "Replaced #{attribute_name} attribute (invalid ID: #{data[:invalid_id]}) with placeholder: #{placeholder_value}",
          node,
        )
      end
    end
  end
end
