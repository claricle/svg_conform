# frozen_string_literal: true

require_relative "base_requirement"

module SvgConform
  module Requirements
    # Requirement to validate that ID references point to existing elements
    # Based on the Lucid SVG fix script that removes use elements with invalid IDREF
    class InvalidIdReferencesRequirement < BaseRequirement
      attribute :type, :string, default: -> { "InvalidIdReferencesRequirement" }
      attribute :check_use_elements, :boolean, default: true
      attribute :check_other_references, :boolean, default: false
      attribute :strict_mode, :boolean, default: false

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "type", to: :type
        map "check_use_elements", to: :check_use_elements
        map "check_other_references", to: :check_other_references
        map "strict_mode", to: :strict_mode
      end

      def initialize(*args)
        super
        # No instance state - validation state stored in context
      end

      # State class for tracking ID references during SAX parsing
      class State
        attr_accessor :collected_ids, :use_element_refs, :other_refs,
                      :existing_ids

        def initialize
          @collected_ids = Set.new
          @use_element_refs = []
          @other_refs = []
          @existing_ids = nil
        end
      end

      def needs_deferred_validation?
        true
      end

      def collect_sax_data(element, context)
        state = context.state_for(self)

        # Collect IDs
        id_attr = element.raw_attributes["id"]
        if id_attr && !id_attr.empty?
          state.collected_ids.add(id_attr)
        end

        # Collect use element references
        if check_use_elements && element.name == "use"
          href = element.raw_attributes["xlink:href"] || element.raw_attributes["href"]
          if href&.start_with?("#")
            ref_id = href[1..]
            unless ref_id.empty?
              state.use_element_refs << [element, ref_id, href]
            end
          end
        end

        # Collect other ID references if enabled
        if check_other_references
          id_reference_attributes = %w[clip-path mask filter marker-start
                                       marker-mid marker-end fill stroke]

          id_reference_attributes.each do |attr_name|
            attr_value = element.raw_attributes[attr_name]
            next unless attr_value&.match?(/^url\(#(.+)\)$/)

            ref_id = Regexp.last_match(1)
            state.other_refs << [element, ref_id, attr_name, attr_value]
          end

          # Check style attribute
          style_value = element.raw_attributes["style"]
          if style_value
            styles = parse_style(style_value)
            styles.each do |property, value|
              next unless value&.match?(/^url\(#(.+)\)$/)

              ref_id = Regexp.last_match(1)
              state.other_refs << [element, ref_id, "style:#{property}", value]
            end
          end
        end
      end

      def validate_sax_complete(context)
        state = context.state_for(self)
        collected_ids = state.collected_ids
        use_element_refs = state.use_element_refs
        other_refs = state.other_refs

        return unless collected_ids && use_element_refs && other_refs

        # Validate use element references
        use_element_refs.each do |element, ref_id, href|
          next if collected_ids.include?(ref_id)

          context.add_error(
            requirement_id: id,
            node: element,
            message: "use element references non-existent ID: #{ref_id}",
            severity: :error,
            data: { invalid_id: ref_id, href: href },
          )
        end

        # Validate other references if enabled
        other_refs.each do |element, ref_id, attr_name, value|
          next if collected_ids.include?(ref_id)

          message = if attr_name.start_with?("style:")
                      property = attr_name.split(":", 2)[1]
                      "style property #{property} references non-existent ID: #{ref_id}"
                    else
                      "#{attr_name} references non-existent ID: #{ref_id}"
                    end

          context.add_error(
            requirement_id: id,
            node: element,
            message: message,
            severity: :error,
            data: { invalid_id: ref_id, attribute: attr_name, value: value },
          )
        end
      end

      def validate_document(document, context)
        # Collect all existing IDs in the document
        existing_ids = collect_existing_ids(document)
        state = context.state_for(self)
        state.existing_ids = existing_ids

        # Check for invalid references
        super
      end

      def check(node, context)
        return unless element?(node)

        if check_use_elements && node.name == "use"
          check_use_element(node,
                            context)
        end

        return unless check_other_references

        check_other_id_references(node, context)
      end

      private

      def collect_existing_ids(document)
        ids = Set.new
        document.traverse do |node|
          next unless element?(node)

          id_attr = get_attribute(node, "id")
          ids.add(id_attr) if id_attr && !id_attr.empty?
        end
        ids
      end

      def check_use_element(node, context)
        state = context.state_for(self)
        href = get_attribute(node, "xlink:href") || get_attribute(node, "href")
        return unless href&.start_with?("#")

        id_ref = href[1..] # Remove # prefix
        return if id_ref.empty?

        existing_ids = state.existing_ids
        return if existing_ids.include?(id_ref)

        context.add_error(
          requirement: self,
          node: node,
          message: "use element references non-existent ID: #{id_ref}",
          data: { invalid_id: id_ref, href: href },
        )
      end

      def check_other_id_references(node, context)
        state = context.state_for(self)

        # Check other attributes that reference IDs
        id_reference_attributes = %w[
          clip-path mask filter marker-start marker-mid marker-end
          fill stroke
        ]

        existing_ids = state.existing_ids

        id_reference_attributes.each do |attr_name|
          attr_value = get_attribute(node, attr_name)
          next unless attr_value

          # Extract ID from url(#id) format
          next unless attr_value =~ /^url\(#(.+)\)$/

          id_ref = Regexp.last_match(1)
          next if existing_ids.include?(id_ref)

          context.add_error(
            requirement: self,
            node: node,
            message: "#{attr_name} references non-existent ID: #{id_ref}",
            data: { invalid_id: id_ref, attribute: attr_name,
                    value: attr_value },
          )
        end

        # Check style attribute for ID references
        check_style_id_references(node, context, existing_ids)
      end

      def check_style_id_references(node, context, existing_ids)
        style_value = get_attribute(node, "style")
        return unless style_value

        styles = parse_style(style_value)

        styles.each do |property, value|
          next unless value =~ /^url\(#(.+)\)$/

          id_ref = Regexp.last_match(1)
          next if existing_ids.include?(id_ref)

          context.add_error(
            requirement: self,
            node: node,
            message: "style property #{property} references non-existent ID: #{id_ref}",
            data: { invalid_id: id_ref, style_property: property,
                    value: value },
          )
        end
      end
    end
  end
end
