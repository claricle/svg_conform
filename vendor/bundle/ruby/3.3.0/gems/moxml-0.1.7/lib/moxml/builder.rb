# frozen_string_literal: true

module Moxml
  class Builder
    def initialize(context)
      @context = context
      @current = @document = context.create_document
      @namespaces = {}
    end

    def build(&block)
      instance_eval(&block)
      @document
    end

    def declaration(version: "1.0", encoding: "UTF-8", standalone: nil)
      @current.add_child(
        @document.create_declaration(version, encoding, standalone)
      )
    end

    def element(name, attributes = {}, &block)
      el = @document.create_element(name)

      attributes.each do |key, value|
        el[key] = value
      end

      @current.add_child(el)

      if block_given?
        previous = @current
        @current = el
        instance_eval(&block)
        @current = previous
      end

      el
    end

    def text(content)
      @current.add_child(@document.create_text(content))
    end

    def cdata(content)
      @current.add_child(@document.create_cdata(content))
    end

    def comment(content)
      @current.add_child(@document.create_comment(content))
    end

    def processing_instruction(target, content)
      @current.add_child(
        @document.create_processing_instruction(target, content)
      )
    end

    def namespace(prefix, uri)
      @current.add_namespace(prefix, uri)
      @namespaces[prefix] = uri
    end
  end
end
