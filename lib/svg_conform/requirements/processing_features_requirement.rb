# frozen_string_literal: true

require_relative "base_requirement"
require_relative "../validation/css_references"

module SvgConform
  module Requirements
    # Rejects processing features that a static profile does not allow.
    #
    # Each configured category (for example script, animation, interaction)
    # carries its own requirement ID and normative citation, so a profile can
    # report them as separate rules. DOM and SAX validation share #check_names.
    class ProcessingFeaturesRequirement < BaseRequirement
      # One rejected feature group
      class Category < Lutaml::Model::Serializable
        attribute :name, :string
        attribute :id, :string
        attribute :citation, :string
        attribute :description, :string
        attribute :elements, :string, collection: true, default: -> { [] }
        attribute :attributes, :string, collection: true, default: -> { [] }
        attribute :attribute_patterns, :string, collection: true,
                                                default: -> { [] }

        yaml do
          map "name", to: :name
          map "id", to: :id
          map "citation", to: :citation
          map "description", to: :description
          map "elements", to: :elements
          map "attributes", to: :attributes
          map "attribute_patterns", to: :attribute_patterns
        end

        def rejects_element?(local_name)
          elements.include?(local_name)
        end

        def rejects_attribute?(local_name)
          attributes.include?(local_name) || matches_pattern?(local_name)
        end

        # CSS property names are checked against the attribute patterns only:
        # the listed attribute names (cursor, begin, ...) are SVG attributes,
        # not CSS declarations. Vendor prefixes (-webkit-) are ignored.
        def rejects_css_property?(property)
          matches_pattern?(property.downcase.sub(/\A-[a-z]+-/, ""))
        end

        # @keyframes only exists to drive CSS animation.
        def rejects_keyframes?
          rejects_css_property?("animation-name")
        end

        private

        def matches_pattern?(name)
          attribute_patterns.any? { |pattern| Regexp.new(pattern).match?(name) }
        end
      end

      attribute :type, :string,
                default: -> { "ProcessingFeaturesRequirement" }
      attribute :categories, Category, collection: true, default: -> { [] }

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "type", to: :type
        map "categories", to: :categories
      end

      def needs_deferred_validation?
        true
      end

      def check(node, context)
        return unless element?(node)

        attrs = (node.attributes || []).to_h { |attr| [attr.name.to_s, attr.value.to_s] }
        check_names(node, local_name(node.name), attrs.keys, context)
        check_css(node, attrs["style"], context)
        check_css(node, node.text.to_s, context) if style_element?(node.name)
      end

      def collect_sax_data(element, context)
        names = element.attributes.map { |attr| attr.name.to_s }
        check_names(element, local_name(element.name), names, context)
        check_css(element, element.raw_attributes["style"]&.to_s, context)
        context.state_for(self).style_elements << element if style_element?(element.name)
      end

      def validate_sax_complete(context)
        context.state_for(self).style_elements.each do |element|
          check_css(element, element.text_content.to_s, context)
        end
      end

      # Style elements seen while streaming; their text is only complete at the end
      class State
        attr_reader :style_elements

        def initialize
          @style_elements = []
        end
      end

      private

      def style_element?(name)
        local_name(name) == "style"
      end

      # Declarations in a style attribute or style element content. Tokenized,
      # so escaped property names (\61nimation) are decoded and text inside
      # strings or comments is ignored.
      def check_css(node, css, context)
        return if css.nil? || css.empty?

        Validation::CssReferences.declarations(css).each do |feature|
          categories.each do |category|
            next unless css_rejected?(category, feature)

            report(context, node, category,
                   "#{category.name} feature: #{feature.description} " \
                   "is not allowed in static processing")
          end
        end
      end

      def css_rejected?(category, feature)
        if feature.keyframes
          category.rejects_keyframes?
        else
          category.rejects_css_property?(feature.name)
        end
      end

      def check_names(node, element_name, attribute_names, context)
        reported = []
        categories.each do |category|
          if category.rejects_element?(element_name)
            report(context, node, category,
                   "#{category.name} feature: element '#{element_name}' " \
                   "is not allowed in static processing")
          end

          attribute_names.each do |attr_name|
            next if reported.include?(attr_name)
            next unless category.rejects_attribute?(attr_name)

            reported << attr_name
            report(context, node, category,
                   "#{category.name} feature: attribute '#{attr_name}' " \
                   "is not allowed in static processing")
          end
        end
      end

      def report(context, node, category, message)
        context.add_error(
          requirement_id: category.id || id,
          message: message,
          node: node,
          severity: :error,
          data: { category: category.name, citation: category.citation },
        )
      end

      def local_name(name)
        name.to_s.split(":").last
      end
    end
  end
end
