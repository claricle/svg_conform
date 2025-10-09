# frozen_string_literal: true

module SvgConform
  module ExternalCheckers
    module Svgcheck
      # Compatibility engine for matching svg_conform behavior to svgcheck
      class CompatibilityEngine
        def initialize
          # Load any compatibility-specific configuration
        end

        # Check if file should be treated as unparseable by svgcheck
        def should_mimic_parse_failure?(_filename, _validation_result)
          # Implement parse failure detection logic based on svgcheck behavior
          # For now, return false - this would need to be enhanced based on actual svgcheck behavior
          false
        end

        # Check if validity errors should be included as regular errors (for svgcheck compatibility)
        def should_include_validity_errors?(validation_result, filename)
          # Include validity errors if both width and height are present
          # This matches svgcheck's behavior from the mapping config
          return false unless validation_result.validity_errors.any?

          # Check for specific datatype condition mentioned in mapping config
          has_width_and_height_datatype_condition?(validation_result, filename)
        end

        # Filter errors for svgcheck compatibility
        def filter_errors_for_svgcheck(errors, _filename, _validation_result)
          filtered_errors = []

          errors.each do |error|
            # Skip namespace_validation errors only for RDF/metadata namespaces
            # svgcheck skips these silently, but reports other namespace errors
            # Only skip RDF-related namespace errors
            if (error.requirement_id == "namespace_validation") && rdf_namespace_error?(error)
              next
            end

            # Map svg_conform requirement IDs to svgcheck-compatible ones
            mapped_req_id = map_requirement_id(error.requirement_id)
            next if mapped_req_id.nil? # Skip unmapped requirements

            filtered_errors << [error, mapped_req_id]
          end

          filtered_errors
        end

        private

        def rdf_namespace_error?(error)
          return false unless error.respond_to?(:message)

          # List of RDF/metadata namespaces that svgcheck silently skips
          rdf_namespaces = [
            "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
            "http://creativecommons.org/ns#",
            "http://purl.org/dc/elements/1.1/",
            "http://purl.org/dc/dcmitype/",
            "http://www.w3.org/2000/01/rdf-schema#",
          ]

          rdf_namespaces.any? { |ns| error.message.include?(ns) }
        end

        def has_width_and_height_datatype_condition?(validation_result,
_filename)
          # This would need to be implemented based on the specific logic
          # mentioned in the mapping config's "datatype_condition": "both_width_and_height_present"
          # For now, return true if there are validity errors
          validation_result.validity_errors.any?
        end

        def map_requirement_id(requirement_id)
          # Map svg_conform requirement IDs to svgcheck-compatible requirement IDs
          mapping = {
            "allowed_elements" => "allowed_elements",
            "namespace_attributes" => "namespace_attributes",
            "namespace_validation" => "namespace_attributes", # Map to closest equivalent
            "font_family" => "style", # svgcheck reports font-family issues as style errors
            "color_restrictions" => "color_restrictions",
            "viewbox_required" => "viewbox_required",
            "style" => "style", # Direct mapping for StyleRequirement
            "style_promotion" => "style",
            "style_syntax" => "style",
            "style_validation" => "style",
            "property_value" => "style",
            "required_attribute" => "viewbox_required",
            "namespace" => "namespace_attributes",
          }

          # Return nil for unmapped requirements (like invalid_id_references)
          mapping[requirement_id.to_s]
        end

        # Extract semantic meaning from error for comparison
        def extract_semantic_meaning(error)
          # Ensure we have a valid error object
          return "unknown" unless error.respond_to?(:message) && error.respond_to?(:requirement_id)

          # Try to create a semantic key based on the error type and context
          requirement = error.requirement_id
          message = error.message

          # Handle different types of errors semantically
          case requirement
          when "color_restrictions"
            # Extract color and attribute for semantic grouping
            if message&.include?("doesn't allow") && (match = message.match(/attribute ['"]([^'"]+)['"].*value ['"]([^'"]+)['"]/))
              attribute = match[1]
              value = match[2]
              "color_restriction:#{attribute}:#{value}"
            else
              requirement
            end
          when "font_family"
            # Group font family errors by attribute and font
            if message&.include?("font-family") && (match = message.match(/font-family.*['"]([^'"]+)['"]/))
              font = match[1]
              "font_restriction:#{font}"
            else
              requirement
            end
          when "allowed_elements"
            # Group by element type
            if message&.include?("not allowed") && (match = message.match(/Element ['"]([^'"]+)['"]/))
              element = match[1]
              "element_not_allowed:#{element}"
            elsif message&.include?("does not allow the attribute") && (match = message.match(/element ['"]([^'"]+)['"].*attribute ['"]([^'"]+)['"]/))
              element = match[1]
              attribute = match[2]
              "invalid_attribute:#{element}:#{attribute}"
            else
              requirement
            end
          when "namespace_attributes"
            # Group by namespace issues
            if message&.include?("namespace") && (match = message.match(/namespace ['"]([^'"]+)['"]/))
              namespace = match[1]
              "namespace_issue:#{namespace}"
            else
              requirement
            end
          when "viewbox_required"
            # ViewBox is generally consistent
            "viewbox_required"
          when "style"
            # Group style issues by property
            if message&.include?("style") && (match = message.match(/property ['"]([^'"]+)['"]/))
              property = match[1]
              "style_issue:#{property}"
            else
              requirement
            end
          else
            # Fallback to requirement_id for other cases
            requirement || "unknown"
          end
        end
      end
    end
  end
end
