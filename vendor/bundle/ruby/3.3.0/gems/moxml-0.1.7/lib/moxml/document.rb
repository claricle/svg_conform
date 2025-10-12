# frozen_string_literal: true

require_relative "node"
require_relative "element"
require_relative "text"
require_relative "cdata"
require_relative "comment"
require_relative "processing_instruction"
require_relative "declaration"
require_relative "namespace"
require_relative "doctype"

module Moxml
  class Document < Node
    def root=(element)
      adapter.set_root(@native, element.native)
    end

    def root
      root_element = adapter.root(@native)
      root_element ? Element.wrap(root_element, context) : nil
    end

    def create_element(name)
      Element.new(adapter.create_element(name), context)
    end

    def create_text(content)
      Text.new(adapter.create_text(content), context)
    end

    def create_cdata(content)
      Cdata.new(adapter.create_cdata(content), context)
    end

    def create_comment(content)
      Comment.new(adapter.create_comment(content), context)
    end

    def create_doctype(name, external_id, system_id)
      Doctype.new(
        adapter.create_doctype(name, external_id, system_id),
        context
      )
    end

    def create_processing_instruction(target, content)
      ProcessingInstruction.new(
        adapter.create_processing_instruction(target, content),
        context
      )
    end

    def create_declaration(version = "1.0", encoding = "UTF-8", standalone = nil)
      decl = adapter.create_declaration(version, encoding, standalone)
      Declaration.new(decl, context)
    end

    def add_child(node)
      node = prepare_node(node)

      if node.is_a?(Declaration)
        if children.empty?
          adapter.add_child(@native, node.native)
        else
          adapter.add_previous_sibling(adapter.children(@native).first, node.native)
        end
      elsif root && !node.is_a?(ProcessingInstruction) && !node.is_a?(Comment)
        raise Error, "Document already has a root element"
      else
        adapter.add_child(@native, node.native)
      end
      self
    end

    def xpath(expression, namespaces = nil)
      native_nodes = adapter.xpath(@native, expression, namespaces)
      NodeSet.new(native_nodes, context)
    end

    def at_xpath(expression, namespaces = nil)
      if (native_node = adapter.at_xpath(@native, expression, namespaces))
        Node.wrap(native_node, context)
      end
    end
  end
end
