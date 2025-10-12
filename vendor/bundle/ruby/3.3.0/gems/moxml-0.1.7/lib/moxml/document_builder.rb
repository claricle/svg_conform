# frozen_string_literal: true

module Moxml
  class DocumentBuilder
    attr_reader :context

    def initialize(context)
      @context = context
      @node_stack = []
    end

    def build(native_doc)
      @current_doc = context.create_document(native_doc)
      visit_node(native_doc)
      @current_doc
    end

    private

    def visit_node(node)
      method_name = "visit_#{node_type(node)}"
      return unless respond_to?(method_name, true)

      send(method_name, node)
    end

    def visit_document(doc)
      @node_stack.push(@current_doc)
      visit_children(doc)
      @node_stack.clear
    end

    def visit_element(node)
      childless_node = adapter.duplicate_node(node)
      adapter.replace_children(childless_node, [])
      element = Element.new(childless_node, context)
      @node_stack.last.add_child(element)

      @node_stack.push(element) # add a parent for its children
      visit_children(node)
      @node_stack.pop # remove the parent
    end

    def visit_text(node)
      @node_stack.last&.add_child(Text.new(node, context))
    end

    def visit_cdata(node)
      @node_stack.last&.add_child(Cdata.new(node, context))
    end

    def visit_comment(node)
      @node_stack.last&.add_child(Comment.new(node, context))
    end

    def visit_processing_instruction(node)
      @node_stack.last&.add_child(ProcessingInstruction.new(node, context))
    end

    def visit_doctype(node)
      @node_stack.last&.add_child(Doctype.new(node, context))
    end

    def visit_children(node)
      node_children = children(node).dup
      node_children.each do |child|
        visit_node(child)
      end
    end

    def node_type(node)
      context.config.adapter.node_type(node)
    end

    def children(node)
      context.config.adapter.children(node)
    end

    def adapter
      context.config.adapter
    end
  end
end
