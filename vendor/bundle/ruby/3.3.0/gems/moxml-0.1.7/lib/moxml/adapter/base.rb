# frozen_string_literal: true

require_relative "../xml_utils"
require_relative "../document_builder"

module Moxml
  module Adapter
    class Base
      # include XmlUtils

      class << self
        include XmlUtils

        def set_root(doc, element)
          raise NotImplementedError
        end

        def parse(xml, options = {})
          raise NotImplementedError
        end

        def create_document(native_doc = nil)
          raise NotImplementedError
        end

        def create_element(name)
          validate_element_name(name)
          create_native_element(name)
        end

        def create_text(content)
          # Ox freezes the content, so we need to dup it
          create_native_text(normalize_xml_value(content).dup)
        end

        def create_cdata(content)
          create_native_cdata(normalize_xml_value(content))
        end

        def create_comment(content)
          validate_comment_content(content)
          create_native_comment(normalize_xml_value(content))
        end

        def create_doctype(name, external_id, system_id)
          create_native_doctype(name, external_id, system_id)
        end

        def create_processing_instruction(target, content)
          validate_pi_target(target)
          create_native_processing_instruction(target, normalize_xml_value(content))
        end

        def create_declaration(version = "1.0", encoding = "UTF-8", standalone = nil)
          validate_declaration_version(version)
          validate_declaration_encoding(encoding)
          validate_declaration_standalone(standalone)
          create_native_declaration(version, encoding, standalone)
        end

        def create_namespace(element, prefix, uri)
          validate_prefix(prefix) if prefix
          validate_uri(uri)
          create_native_namespace(element, prefix, uri)
        end

        def set_attribute_name(attribute, name)
          attribute.name = name
        end

        def set_attribute_value(attribute, value)
          attribute.value = value
        end

        def duplicate_node(node)
          node.dup
        end

        def patch_node(node, _parent = nil)
          # monkey-patch the native node if necessary
          node
        end

        protected

        def create_native_element(name)
          raise NotImplementedError
        end

        def create_native_text(content)
          raise NotImplementedError
        end

        def create_native_cdata(content)
          raise NotImplementedError
        end

        def create_native_comment(content)
          raise NotImplementedError
        end

        def create_native_doctype(name, external_id, system_id)
          raise NotImplementedError
        end

        def create_native_processing_instruction(target, content)
          raise NotImplementedError
        end

        def create_native_declaration(version, encoding, standalone)
          raise NotImplementedError
        end

        def create_native_namespace(element, prefix, uri)
          raise NotImplementedError
        end
      end
    end
  end
end
