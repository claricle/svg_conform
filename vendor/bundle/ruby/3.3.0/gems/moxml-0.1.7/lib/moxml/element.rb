# frozen_string_literal: true

require_relative "attribute"
require_relative "namespace"

module Moxml
  class Element < Node
    def name
      adapter.node_name(@native)
    end

    def name=(value)
      adapter.set_node_name(@native, value)
    end

    def []=(name, value)
      adapter.set_attribute(@native, name, normalize_xml_value(value))
    end

    def [](name)
      adapter.get_attribute_value(@native, name)
    end

    def attribute(name)
      native_attr = adapter.get_attribute(@native, name)
      native_attr && Attribute.new(native_attr, context)
    end

    def attributes
      adapter.attributes(@native).map do |attr|
        Attribute.new(attr, context)
      end
    end

    def remove_attribute(name)
      adapter.remove_attribute(@native, name)
      self
    end

    def add_namespace(prefix, uri)
      validate_uri(uri)
      adapter.create_native_namespace(@native, prefix, uri)
      self
    rescue ValidationError => e
      raise Moxml::NamespaceError, e.message
    end
    alias add_namespace_definition add_namespace

    # it's NOT the same as namespaces.first
    def namespace
      ns = adapter.namespace(@native)
      ns && Namespace.new(ns, context)
    end

    # add the prefix to the element name
    # and add the namespace to the list of namespace definitions
    def namespace=(ns_or_hash)
      if ns_or_hash.is_a?(Hash)
        adapter.set_namespace(
          @native,
          adapter.create_namespace(@native, *ns_or_hash.to_a.first)
        )
      else
        adapter.set_namespace(@native, ns_or_hash&.native)
      end
    end

    def namespaces
      adapter.namespace_definitions(@native).map do |ns|
        Namespace.new(ns, context)
      end
    end
    alias namespace_definitions namespaces

    def text
      adapter.text_content(@native)
    end

    def text=(content)
      adapter.set_text_content(@native, normalize_xml_value(content))
    end

    def inner_text
      adapter.inner_text(@native)
    end

    def inner_xml
      adapter.inner_xml(@native)
    end

    def inner_xml=(xml)
      doc = context.parse("<root>#{xml}</root>")
      adapter.replace_children(@native, doc.root.children.map(&:native))
    end

    # Fluent interface methods
    def with_attribute(name, value)
      self[name] = value
      self
    end

    def with_namespace(prefix, uri)
      add_namespace(prefix, uri)
      self
    end

    def with_text(content)
      self.text = content
      self
    end
  end
end
