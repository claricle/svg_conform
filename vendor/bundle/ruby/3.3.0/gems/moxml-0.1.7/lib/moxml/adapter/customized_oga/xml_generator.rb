# rubocop:disable Style/FrozenStringLiteralComment

require "oga"

# monkey patch the Oga generator because it's not configurable
# https://github.com/yorickpeterse/oga/blob/main/lib/oga/xml/generator.rb
module Moxml
  module Adapter
    module CustomizedOga
      class XmlGenerator < ::Oga::XML::Generator
        def self_closing?(_element)
          # Always expand tags
          false
        end

        def on_element(element, output)
          name = element.expanded_name

          attrs = ""
          element.attributes.each do |attr|
            attrs << " "
            on_attribute(attr, attrs)
          end

          closing_tag = if self_closing?(element)
                          html_void_element?(element) ? ">" : " />"
                        else
                          ">"
                        end

          output << "<#{name}#{attrs}#{closing_tag}"
        end

        def on_namespace_definition(ns, output)
          name = "xmlns"
          name += ":#{ns.name}" unless ns.name.nil?

          output << %(#{name}="#{ns.uri}")
        end

        def on_attribute(attr, output)
          return super unless attr.value&.include?("'")

          output << %(#{attr.expanded_name}="#{encode(attr.value)}")
        end

        def on_cdata(node, output)
          # Escape the end sequence
          return super unless node.text.include?("]]>")

          chunks = node.text.split(/(\]\]>)/)
          chunks = ["]]", ">"] if chunks.size == 1

          while (index = chunks.index("]]>"))
            # the end tag cannot be the first and the last at the same time

            if index.zero?
              # it's the first text chunk
              chunks[index] = "]]"
              chunks[index + 1] = ">#{chunks[index + 1]}"
            elsif index - 1 == chunks.size
              # it's the last text chunk
              chunks[index - 1] += "]]"
              chunks[index] = ">"
            else
              # it's a chunk in the middle
              chunks[index - 1] += "]]"
              chunks[index + 1] = ">#{chunks[index + 1]}"
              chunks.delete_at(index)
            end
          end

          chunks.each do |chunk|
            output << "<![CDATA[#{chunk}]]>"
          end

          output
        end

        def on_processing_instruction(node, output)
          # put the space between the name and text
          output << "<?#{node.name} #{node.text}?>"
        end

        def on_xml_declaration(node, output)
          super
          # remove the space before the closing tag
          output.gsub!(/ \?>$/, "?>")
        end

        protected

        def encode(input)
          # similar to ::Oga::XML::Entities.encode_attribute
          input&.gsub(
            ::Oga::XML::Entities::ENCODE_ATTRIBUTE_REGEXP,
            # Keep apostrophes in attributes
            ::Oga::XML::Entities::ENCODE_ATTRIBUTE_MAPPING.merge("'" => "'")
          )
        end
      end
    end
  end
end
