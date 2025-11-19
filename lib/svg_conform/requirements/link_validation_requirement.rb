# frozen_string_literal: true

require_relative "base_requirement"

module SvgConform
  module Requirements
    class LinkValidationRequirement < BaseRequirement
      def check(node, context)
        return unless element?(node)

        # Check href attributes (both href and xlink:href)
        href_value = get_attribute(node, "href")

        # Check for xlink:href if regular href is not present
        if href_value.nil? && node.respond_to?(:attributes)
          xlink_href = node.attributes.find do |attr|
            attr.name == "href" && attr.namespace&.uri == "http://www.w3.org/1999/xlink"
          end
          href_value = xlink_href&.value
        end

        if href_value && !ascii_only?(href_value)
          context.add_error(
            requirement_id: id,
            message: "Link href '#{href_value}' contains non-ASCII characters",
            node: node,
            severity: :error,
          )
        end

        # Check other IRI attributes
        iri_attributes = %w[src action formaction cite longdesc usemap]
        iri_attributes.each do |attr_name|
          iri_value = get_attribute(node, attr_name)
          next unless iri_value

          next if ascii_only?(iri_value)

          context.add_error(
            requirement_id: id,
            message: "IRI attribute '#{attr_name}' value '#{iri_value}' contains non-ASCII characters",
            node: node,
            severity: :error,
          )
        end
      end

      def validate_sax_element(element, context)
        # Check href attributes
        href_value = element.raw_attributes["href"] || element.raw_attributes["xlink:href"]

        if href_value && !ascii_only?(href_value)
          context.add_error(
            requirement_id: id,
            message: "Link href '#{href_value}' contains non-ASCII characters",
            node: element,
            severity: :error,
          )
        end

        # Check other IRI attributes
        iri_attributes = %w[src action formaction cite longdesc usemap]
        iri_attributes.each do |attr_name|
          iri_value = element.raw_attributes[attr_name]
          next unless iri_value

          next if ascii_only?(iri_value)

          context.add_error(
            requirement_id: id,
            message: "IRI attribute '#{attr_name}' value '#{iri_value}' contains non-ASCII characters",
            node: element,
            severity: :error,
          )
        end
      end

      private

      def ascii_only?(string)
        string.ascii_only?
      end
    end
  end
end
