# frozen_string_literal: true

require_relative "base"
require "rexml/document"
require "rexml/xpath"
require "set"
require_relative "customized_rexml/formatter"

module Moxml
  module Adapter
    class Rexml < Base
      class << self
        def parse(xml, options = {})
          native_doc = begin
            ::REXML::Document.new(xml)
          rescue ::REXML::ParseException => e
            raise Moxml::ParseError.new(e.message, line: e.line) if options[:strict]

            create_document
          end
          DocumentBuilder.new(Context.new(:rexml)).build(native_doc)
        end

        def create_document(_native_doc = nil)
          ::REXML::Document.new
        end

        def create_native_element(name)
          ::REXML::Element.new(name.to_s)
        end

        def create_native_text(content)
          ::REXML::Text.new(content.to_s, true, nil)
        end

        def create_native_cdata(content)
          ::REXML::CData.new(content.to_s)
        end

        def create_native_comment(content)
          ::REXML::Comment.new(content.to_s)
        end

        def create_native_processing_instruction(target, content)
          # Clone strings to avoid frozen string errors
          ::REXML::Instruction.new(target.to_s.dup, content.to_s.dup)
        end

        def create_native_declaration(version, encoding, standalone)
          ::REXML::XMLDecl.new(version, encoding&.downcase, standalone)
        end

        def create_native_doctype(name, external_id, system_id)
          return nil unless name

          parts = [name]
          if external_id
            parts.concat(["PUBLIC", %("#{external_id}")])
            parts << %("#{system_id}") if system_id
          elsif system_id
            parts.concat(["SYSTEM", %("#{system_id}")])
          end

          ::REXML::DocType.new(parts.join(" "))
        end

        def set_root(doc, element)
          doc.add_element(element)
        end

        def node_type(node)
          case node
          when ::REXML::Document then :document
          when ::REXML::Element then :element
          when ::REXML::CData then :cdata
          when ::REXML::Text then :text
          when ::REXML::Comment then :comment
          when ::REXML::Attribute then :attribute # but in fact it may be a namespace as well
          when ::REXML::Namespace then :namespace # we don't use this one
          when ::REXML::Instruction then :processing_instruction
          when ::REXML::DocType then :doctype
          when ::REXML::XMLDecl then :declaration
          else :unknown
          end
        end

        def set_node_name(node, name)
          case node
          when ::REXML::Element
            node.name = name.to_s
          when ::REXML::Instruction
            node.target = name.to_s
          end
        end

        def node_name(node)
          case node
          when ::REXML::Element, ::REXML::DocType
            node.name
          when ::REXML::XMLDecl
            "xml"
          when ::REXML::Instruction
            node.target
          end
        end

        def duplicate_node(node)
          # Make a complete duplicate of the node
          # https://stackoverflow.com/questions/23878384/why-the-original-element-got-changed-when-i-modify-the-copy-created-by-dup-meth
          Marshal.load(Marshal.dump(node))
        end

        def children(node)
          return [] unless node.respond_to?(:children)

          # Get all children and filter out empty text nodes between elements
          result = node.children.reject do |child|
            child.is_a?(::REXML::Text) &&
              child.to_s.strip.empty? &&
              !(child.next_sibling.nil? && child.previous_sibling.nil?)
          end

          # Ensure uniqueness by object_id to prevent duplicates
          result.uniq(&:object_id)
        end

        def parent(node)
          node.parent
        end

        def next_sibling(node)
          current = node.next_sibling

          # Skip empty text nodes and duplicates
          seen = Set.new
          while current
            if current.is_a?(::REXML::Text) && current.to_s.strip.empty?
              current = current.next_sibling
              next
            end

            # Check for duplicates
            if seen.include?(current.object_id)
              current = current.next_sibling
              next
            end

            seen.add(current.object_id)
            break
          end

          current
        end

        def previous_sibling(node)
          current = node.previous_sibling

          # Skip empty text nodes and duplicates
          seen = Set.new
          while current
            if current.is_a?(::REXML::Text) && current.to_s.strip.empty?
              current = current.previous_sibling
              next
            end

            # Check for duplicates
            if seen.include?(current.object_id)
              current = current.previous_sibling
              next
            end

            seen.add(current.object_id)
            break
          end

          current
        end

        def document(node)
          node.document
        end

        def root(document)
          document.root
        end

        def attributes(element)
          return [] unless element.respond_to?(:attributes)

          # Only return non-namespace attributes
          element.attributes.values
                 .reject { |attr| attr.prefix.to_s.start_with?("xmlns") }
        end

        def attribute_element(attribute)
          attribute.element
        end

        def set_attribute(element, name, value)
          element.attributes[name&.to_s] = value
          ::REXML::Attribute.new(name&.to_s, value.to_s, element)
        end

        def set_attribute_name(attribute, name)
          old_name = attribute.expanded_name
          attribute.name = name
          # Rexml doesn't change the keys of the attributes hash
          element = attribute.element
          element.attributes.delete(old_name)
          element.attributes << attribute
        end

        def set_attribute_value(attribute, value)
          attribute.normalized = value
        end

        def get_attribute(element, name)
          element.attributes.get_attribute(name)
        end

        def get_attribute_value(element, name)
          element.attributes[name]
        end

        def remove_attribute(element, name)
          element.delete_attribute(name.to_s)
        end

        def add_child(element, child)
          case child
          when String
            element.add_text(child)
          else
            element.add(child)
          end
        end

        def add_previous_sibling(node, sibling)
          parent = node.parent
          # caveat: Rexml fails if children belong to the same parent and are already in a correct order
          # example: "<root><a/><b/></root>"
          # add_previous_sibling(node_b, node_a)
          # result: "<root><b/><a/></root>"
          # expected result: "<root><a/><b/></root>"
          parent.insert_before(node, sibling)
        end

        def add_next_sibling(node, sibling)
          parent = node.parent
          parent.insert_after(node, sibling)
        end

        def remove(node)
          node.remove
        end

        def replace(node, new_node)
          node.replace_with(new_node)
        end

        def replace_children(element, children)
          element.children.each(&:remove)
          children.each { |child| element.add(child) }
        end

        def declaration_attribute(node, name)
          case name
          when "version"
            node.version
          when "encoding"
            node.encoding
          when "standalone"
            node.standalone
          end
        end

        def set_declaration_attribute(node, name, value)
          case name
          when "version"
            node.version = value
          when "encoding"
            node.encoding = value
          when "standalone"
            node.standalone = value
          end
        end

        def comment_content(node)
          node.string
        end

        def set_comment_content(node, content)
          node.string = content.to_s
        end

        def cdata_content(node)
          node.value
        end

        def set_cdata_content(node, content)
          node.value = content.to_s
        end

        def processing_instruction_target(node)
          node.target
        end

        def processing_instruction_content(node)
          node.content
        end

        def set_processing_instruction_content(node, content)
          node.content = content.to_s
        end

        def text_content(node)
          case node
          when ::REXML::Text, ::REXML::CData
            node.value.to_s
          when ::REXML::Element
            # Get all text nodes, filter out duplicates, and join
            text_nodes = node.texts.uniq(&:object_id)
            text_nodes.map(&:value).join
          end
        end

        def inner_text(node)
          # Get direct text children only, filter duplicates
          text_children = node.children
                              .select { _1.is_a?(::REXML::Text) }
                              .uniq(&:object_id)
          text_children.map(&:value).join
        end

        def set_text_content(node, content)
          case node
          when ::REXML::Text, ::REXML::CData
            node.value = content.to_s
          when ::REXML::Element
            # Remove existing text nodes to prevent duplicates
            node.texts.each(&:remove)
            # Add new text content
            node.add_text(content.to_s)
          end
        end

        # add a namespace definition, keep the element name unchanged
        def create_native_namespace(element, prefix, uri)
          element.add_namespace(prefix.to_s, uri)
          ::REXML::Attribute.new(prefix.to_s, uri, element)
        end

        # add a namespace prefix to the element name AND a namespace definition
        def set_namespace(element, ns)
          prefix = ns.name.to_s.empty? ? "xmlns" : ns.name.to_s
          element.add_namespace(prefix, ns.value) if element.respond_to?(:add_namespace)
          element.name = "#{prefix}:#{element.name}"
          owner = element.is_a?(::REXML::Attribute) ? element.element : element
          ::REXML::Attribute.new(prefix, ns.value, owner)
        end

        def namespace_prefix(node)
          node.name unless node.name == "xmlns"
        end

        def namespace_uri(node)
          node.value
        end

        def namespace(node)
          prefix = node.prefix
          uri = node.namespace(prefix)
          return if prefix.to_s.empty? && uri.to_s.empty?

          owner = node.is_a?(::REXML::Attribute) ? node.element : node
          ::REXML::Attribute.new(prefix, uri, owner)
        end

        def namespace_definitions(node)
          node.namespaces.map do |prefix, uri|
            ::REXML::Attribute.new(prefix.to_s, uri, node)
          end
        end

        # not used at the moment
        # but may be useful when the xpath is upgraded to work with namespaces
        def prepare_xpath_namespaces(node)
          ns = {}

          # Get all namespace definitions in scope
          all_ns = namespace_definitions(node)

          # Convert to XPath-friendly format
          all_ns.each do |prefix, uri|
            if prefix.to_s.empty?
              ns["xmlns"] = uri
            else
              ns[prefix] = uri
            end
          end

          ns
        end

        def xpath(node, expression, _namespaces = {})
          node.get_elements(expression).to_a
        rescue ::REXML::ParseException => e
          raise Moxml::XPathError, e.message
        end

        def at_xpath(node, expression, namespaces = {})
          results = xpath(node, expression, namespaces)
          results.first
        end

        def serialize(node, options = {})
          output = String.new

          if node.is_a?(::REXML::Document)
            # Always include XML declaration
            decl = node.xml_decl || ::REXML::XMLDecl.new("1.0", options[:encoding] || "UTF-8")
            decl.encoding = options[:encoding] if options[:encoding]
            output << "<?xml"
            output << %( version="#{decl.version}") if decl.version
            output << %( encoding="#{decl.encoding}") if decl.encoding
            output << %( standalone="#{decl.standalone}") if decl.standalone
            output << "?>"
            # output << "\n"

            if node.doctype
              node.doctype.write(output)
              # output << "\n"
            end

            # Write processing instructions
            node.children.each do |child|
              next unless [::REXML::Instruction, ::REXML::CData, ::REXML::Comment, ::REXML::Text].include?(child.class)

              write_with_formatter(child, output, options[:indent] || 2)
              # output << "\n"
            end

            write_with_formatter(node.root, output, options[:indent] || 2) if node.root
          else
            write_with_formatter(node, output, options[:indent] || 2)
          end

          output.strip
        end

        private

        def write_with_formatter(node, output, indent = 2)
          formatter = ::Moxml::Adapter::CustomizedRexml::Formatter.new(
            indentation: indent, self_close_empty: false
          )
          formatter.write(node, output)
        end
      end
    end
  end
end
