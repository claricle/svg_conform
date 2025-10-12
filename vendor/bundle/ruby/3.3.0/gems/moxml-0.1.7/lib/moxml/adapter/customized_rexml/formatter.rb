require "rexml/formatters/pretty"

module Moxml
  module Adapter
    module CustomizedRexml
      # Custom REXML formatter that fixes indentation and wrapping issues
      class Formatter < ::REXML::Formatters::Pretty
        def initialize(indentation: 2, self_close_empty: false)
          @indentation = " " * indentation
          @level = 0
          @compact = true
          @width = -1 # Disable line wrapping
          @self_close_empty = self_close_empty
        end

        def write(node, output)
          case node
          when ::REXML::XMLDecl
            write_declaration(node, output)
          else
            super
          end
        end

        def write_element(node, output)
          # output << ' ' * @level
          output << "<#{node.expanded_name}"
          write_attributes(node, output)

          if node.children.empty? && @self_close_empty
            output << "/>"
            return
          end

          output << ">"

          # Check for mixed content
          has_text = node.children.any? { |c| c.is_a?(::REXML::Text) && !c.to_s.strip.empty? }
          has_elements = node.children.any? { |c| c.is_a?(::REXML::Element) }
          mixed = has_text && has_elements

          # Handle children based on content type
          unless node.children.empty?
            @level += @indentation.length unless mixed

            node.children.each_with_index do |child, _index|
              # Skip insignificant whitespace
              next if child.is_a?(::REXML::Text) &&
                      child.to_s.strip.empty? &&
                      !(child.next_sibling.nil? && child.previous_sibling.nil?)

              # Indent non-text nodes in non-mixed content
              # if !mixed && !child.is_a?(::REXML::Text)
              #   output << ' ' * @level
              # end

              write(child, output)

              # Add newlines between elements in non-mixed content
              # if !mixed && !child.is_a?(::REXML::Text) && index < node.children.size - 1
              #   output << "\n"
              # end
            end

            # Reset indentation for closing tag in non-mixed content
            unless mixed
              @level -= @indentation.length
              # output << ' ' * @level
            end
          end

          output << "</#{node.expanded_name}>"
          # output << "\n" unless mixed
        end

        def write_text(node, output)
          text = node.value
          return if text.empty?

          output << escape_text(text)
        end

        def escape_text(text)
          text.to_s.gsub(/[<>&]/) do |match|
            case match
            when "<" then "&lt;"
            when ">" then "&gt;"
            when "&" then "&amp;"
            end
          end
        end

        private

        def find_significant_sibling(node, direction)
          method = direction == :next ? :next_sibling : :previous_sibling
          sibling = node.send(method)
          sibling = sibling.send(method) while sibling && sibling.is_a?(::REXML::Text) && sibling.to_s.strip.empty?
          sibling
        end

        def write_cdata(node, output)
          # output << ' ' * @level
          output << ::REXML::CData::START
          output << node.to_s.gsub(::REXML::CData::STOP, "]]]]><![CDATA[>")
          output << ::REXML::CData::STOP
          # output << "\n"
        end

        def write_comment(node, output)
          # output << ' ' * @level
          output << "<!--"
          output << node.to_s
          output << "-->"
          # output << "\n"
        end

        def write_instruction(node, output)
          # output << ' ' * @level
          output << "<?"
          output << node.target
          output << " "
          output << node.content if node.content
          output << "?>"
          # output << "\n"
        end

        def write_document(node, output)
          node.children.each do |child|
            write(child, output)
            # output << "\n" unless child == node.children.last
          end
        end

        def write_doctype(node, output)
          output << "<!DOCTYPE "
          output << node.name
          output << " "
          output << node.external_id if node.external_id
          output << ">"
          # output << "\n"
        end

        def write_declaration(node, output)
          output << "<?xml"
          output << %( version="#{node.version}") if node.version
          output << %( encoding="#{node.encoding.to_s.upcase}") if node.writeencoding
          output << %( standalone="#{node.standalone}") if node.standalone
          output << "?>"
          # output << "\n"
        end

        def write_attributes(node, output)
          # First write namespace declarations
          node.attributes.each do |name, attr|
            next unless name.to_s.start_with?("xmlns:") || name.to_s == "xmlns"

            name = "xmlns" if name.to_s == "xmlns:" # convert the default namespace
            value = attr.respond_to?(:value) ? attr.value : attr
            output << " #{name}=\"#{value}\""
          end

          # Then write regular attributes
          node.attributes.each do |name, attr|
            next if name.to_s.start_with?("xmlns:") || name.to_s == "xmlns"

            output << " "
            output << if attr.respond_to?(:prefix) && attr.prefix
                        "#{attr.prefix}:#{attr.name}"
                      else
                        name.to_s
                      end

            output << "=\""
            value = attr.respond_to?(:value) ? attr.value : attr
            output << escape_attribute_value(value.to_s)
            output << "\""
          end
        end

        def escape_attribute_value(value)
          value.to_s.gsub(/[<>&"]/) do |match|
            case match
            when "<" then "&lt;"
            when ">" then "&gt;"
            when "&" then "&amp;"
            when '"' then "&quot;"
              # when "'" then '&apos;'
            end
          end
        end
      end
    end
  end
end
