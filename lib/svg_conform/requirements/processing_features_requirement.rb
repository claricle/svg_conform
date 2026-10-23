# frozen_string_literal: true

require_relative "base_requirement"

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
          attributes.include?(local_name) ||
            attribute_patterns.any? { |pattern| Regexp.new(pattern).match?(local_name) }
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

      def check(node, context)
        return unless element?(node)

        names = (node.attributes || []).map { |attr| attr.name.to_s }
        check_names(node, local_name(node.name), names, context)
      end

      def validate_sax_element(element, context)
        names = element.attributes.map { |attr| attr.name.to_s }
        check_names(element, local_name(element.name), names, context)
      end

      private

      def check_names(node, element_name, attribute_names, context)
        categories.each do |category|
          if category.rejects_element?(element_name)
            report(context, node, category,
                   "#{category.name} feature: element '#{element_name}' " \
                   "is not allowed in static processing")
          end

          attribute_names.each do |attr_name|
            next unless category.rejects_attribute?(attr_name)

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
