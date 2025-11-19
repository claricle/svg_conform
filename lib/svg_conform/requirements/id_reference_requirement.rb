# frozen_string_literal: true

require_relative "base_requirement"
require "set"

module SvgConform
  module Requirements
    class IdReferenceRequirement < BaseRequirement
      def needs_deferred_validation?
        true
      end

      def collect_sax_data(element, _context)
        # Initialize collections on first call
        @collected_ids ||= Set.new
        @collected_url_refs ||= []
        @collected_href_refs ||= []
        @collected_other_refs ||= []

        # Collect IDs
        id_value = element.raw_attributes["id"]
        @collected_ids.add(id_value) if id_value && !id_value.empty?

        # Collect url() references
        url_attributes = %w[fill stroke marker-start marker-mid marker-end
                            clip-path mask filter]
        url_attributes.each do |attr_name|
          attr_value = element.raw_attributes[attr_name]
          next unless attr_value

          url_refs = extract_url_references(attr_value)
          url_refs.each do |ref_id|
            @collected_url_refs << [element, ref_id, attr_name]
          end
        end

        # Check style attribute for url() references
        style_attr = element.raw_attributes["style"]
        if style_attr
          url_refs = extract_url_references(style_attr)
          url_refs.each do |ref_id|
            @collected_url_refs << [element, ref_id, "style"]
          end
        end

        # Collect href references
        href_value = element.raw_attributes["href"] || element.raw_attributes["xlink:href"]
        if href_value&.start_with?("#")
          ref_id = href_value[1..] # Remove #
          @collected_href_refs << [element, ref_id]
        end

        # Collect other ID references
        id_ref_attributes = %w[for aria-labelledby aria-describedby
                               aria-controls aria-owns]
        id_ref_attributes.each do |attr_name|
          attr_value = element.raw_attributes[attr_name]
          next unless attr_value

          ref_ids = attr_value.split(/\s+/)
          ref_ids.each do |ref_id|
            next if ref_id.empty?

            @collected_other_refs << [element, ref_id, attr_name]
          end
        end
      end

      def validate_sax_complete(context)
        # Guard against nil collections (if collect_sax_data was never called)
        return unless @collected_url_refs && @collected_href_refs && @collected_other_refs && @collected_ids

        # Validate all collected references
        @collected_url_refs.each do |element, ref_id, attr_name|
          next if @collected_ids.include?(ref_id)

          message = if attr_name == "style"
                      "Reference to undefined ID '#{ref_id}' in style attribute"
                    else
                      "Reference to undefined ID '#{ref_id}' in attribute '#{attr_name}'"
                    end

          context.add_error(
            node: element,
            message: message,
            requirement_id: id,
          )
        end

        @collected_href_refs.each do |element, ref_id|
          next if @collected_ids.include?(ref_id)

          context.add_error(
            node: element,
            message: "Reference to undefined ID '#{ref_id}' in href attribute",
            requirement_id: id,
          )
        end

        @collected_other_refs.each do |element, ref_id, attr_name|
          next if @collected_ids.include?(ref_id)

          context.add_error(
            node: element,
            message: "Reference to undefined ID '#{ref_id}' in #{attr_name} attribute",
            requirement_id: id,
          )
        end
      end

      def validate_document(document, context)
        # Collect all IDs in the document
        ids = Set.new
        document.xpath("//*[@id]").each do |element|
          id_value = element["id"]
          ids.add(id_value) if id_value && !id_value.empty?
        end

        # Check references to IDs
        check_url_references(document, ids, context)
        check_href_references(document, ids, context)
        check_other_references(document, ids, context)
      end

      private

      def check_url_references(document, ids, context)
        # Check url() references in style attributes and CSS properties
        url_attributes = %w[fill stroke marker-start marker-mid marker-end
                            clip-path mask filter]

        url_attributes.each do |attr_name|
          document.xpath("//*[@#{attr_name}]").each do |element|
            attr_value = element[attr_name]
            next unless attr_value

            url_refs = extract_url_references(attr_value)
            url_refs.each do |ref_id|
              next if ids.include?(ref_id)

              context.add_error(
                node: element,
                message: "Reference to undefined ID '#{ref_id}' in attribute '#{attr_name}'",
                requirement_id: id,
              )
            end
          end
        end

        # Check style attributes
        document.xpath("//*[@style]").each do |element|
          style_attr = element["style"]
          next unless style_attr

          url_refs = extract_url_references(style_attr)
          url_refs.each do |ref_id|
            next if ids.include?(ref_id)

            context.add_error(
              node: element,
              message: "Reference to undefined ID '#{ref_id}' in style attribute",
              requirement_id: id,
            )
          end
        end
      end

      def check_href_references(document, ids, context)
        # Check href and xlink:href references
        document.xpath("//*[@href or @*[local-name()='href']]").each do |element|
          href_value = element["href"]

          # Check for xlink:href if regular href is not present
          if href_value.nil?
            href_value = element.attributes.find do |attr|
              attr.name == "href" && attr.namespace&.uri == "http://www.w3.org/1999/xlink"
            end&.value
          end

          next unless href_value

          # Only check fragment identifiers (starting with #)
          next unless href_value.start_with?("#")

          ref_id = href_value[1..] # Remove the #
          next if ids.include?(ref_id)

          context.add_error(
            node: element,
            message: "Reference to undefined ID '#{ref_id}' in href attribute",
            requirement_id: id,
          )
        end
      end

      def check_other_references(document, ids, context)
        # Check other attributes that reference IDs
        id_ref_attributes = %w[for aria-labelledby aria-describedby
                               aria-controls aria-owns]

        id_ref_attributes.each do |attr_name|
          document.xpath("//*[@#{attr_name}]").each do |element|
            attr_value = element[attr_name]
            next unless attr_value

            # These attributes can contain space-separated lists of IDs
            ref_ids = attr_value.split(/\s+/)
            ref_ids.each do |ref_id|
              next if ref_id.empty?

              next if ids.include?(ref_id)

              context.add_error(
                node: element,
                message: "Reference to undefined ID '#{ref_id}' in #{attr_name} attribute",
                requirement_id: id,
              )
            end
          end
        end
      end

      def extract_url_references(value)
        refs = []

        # Match url(#id) patterns
        value.scan(/url\(#([^)]+)\)/) do |match|
          refs << match[0]
        end

        refs
      end
    end
  end
end
