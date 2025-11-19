# frozen_string_literal: true

require_relative "base_requirement"
require_relative "../references/reference_classifier"

module SvgConform
  module Requirements
    class LinkValidationRequirement < BaseRequirement
      def check(node, context)
        return unless element?(node)

        # Check href attributes (both href and xlink:href)
        href_value = extract_href(node)
        return unless href_value

        # Always validate ASCII requirement (applies to all references)
        validate_ascii(href_value, node, context)

        # Classify and register the reference
        reference = classify_reference(href_value, node)
        return unless reference

        context.register_reference(reference)

        # Only validate internal references
        if reference.internally_validatable?
          validate_internal_reference(reference, node, context)
        elsif reference.requires_consumer_validation?
          # Don't error - just notify consumer
          context.add_external_reference_notice(
            node: node,
            reference: reference,
          )
        end

        # Check other IRI attributes
        iri_attributes = %w[src action formaction cite longdesc usemap]
        iri_attributes.each do |attr_name|
          iri_value = get_attribute(node, attr_name)
          next unless iri_value

          validate_ascii_attribute(iri_value, attr_name, node, context)

          # Classify and register these references too
          iri_ref = classify_reference(iri_value, node, attr_name)
          context.register_reference(iri_ref) if iri_ref
        end
      end

      def validate_sax_element(element, context)
        # Check href attributes
        href_value = element.raw_attributes["href"] || element.raw_attributes["xlink:href"]

        if href_value
          validate_ascii(href_value, element, context)

          # Classify and register
          reference = References::ReferenceClassifier.classify(
            href_value,
            element_name: element.name,
            attribute_name: "href",
            line_number: element.line,
            column_number: element.column,
          )

          if reference
            context.register_reference(reference)

            if reference.internally_validatable?
              validate_internal_reference(reference, element, context)
            elsif reference.requires_consumer_validation?
              context.add_external_reference_notice(
                node: element,
                reference: reference,
              )
            end
          end
        end

        # Check other IRI attributes
        iri_attributes = %w[src action formaction cite longdesc usemap]
        iri_attributes.each do |attr_name|
          iri_value = element.raw_attributes[attr_name]
          next unless iri_value

          validate_ascii_attribute(iri_value, attr_name, element, context)

          # Classify and register
          iri_ref = References::ReferenceClassifier.classify(
            iri_value,
            element_name: element.name,
            attribute_name: attr_name,
            line_number: element.line,
            column_number: element.column,
          )
          context.register_reference(iri_ref) if iri_ref
        end
      end

      private

      def extract_href(node)
        href_value = get_attribute(node, "href")
        return href_value if href_value

        # Check for xlink:href if regular href is not present
        if node.respond_to?(:attributes)
          xlink_href = node.attributes.find do |attr|
            attr.name == "href" && attr.namespace&.uri == "http://www.w3.org/1999/xlink"
          end
          xlink_href&.value
        end
      end

      def classify_reference(href_value, node, attr_name = "href")
        References::ReferenceClassifier.classify(
          href_value,
          element_name: node.name,
          attribute_name: attr_name,
          line_number: node.respond_to?(:line) ? node.line : nil,
          column_number: node.respond_to?(:column) ? node.column : nil,
        )
      end

      def validate_ascii(href_value, node, context)
        return if ascii_only?(href_value)

        context.add_error(
          requirement_id: id,
          message: "Link href '#{href_value}' contains non-ASCII characters",
          node: node,
          severity: :error,
        )
      end

      def validate_ascii_attribute(iri_value, attr_name, node, context)
        return if ascii_only?(iri_value)

        context.add_error(
          requirement_id: id,
          message: "IRI attribute '#{attr_name}' value '#{iri_value}' contains non-ASCII characters",
          node: node,
          severity: :error,
        )
      end

      def validate_internal_reference(reference, node, context)
        return unless reference.is_a?(References::InternalFragmentReference)

        target_id = reference.target_id

        # Use manifest to check if ID exists
        unless context.id_defined?(target_id)
          context.add_error(
            requirement_id: id,
            message: "Internal reference '#{reference.value}' points to non-existent element",
            node: node,
            severity: :error,
          )
        end
      end

      def ascii_only?(string)
        string.ascii_only?
      end
    end
  end
end
