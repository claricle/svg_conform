# frozen_string_literal: true

module Moxml
  class NodeSet
    include Enumerable

    attr_reader :nodes, :context

    def initialize(nodes, context)
      @nodes = Array(nodes)
      @context = context
    end

    def each
      return to_enum(:each) unless block_given?

      nodes.each { |node| yield Node.wrap(node, context) }
      self
    end

    def [](index)
      case index
      when Integer
        Node.wrap(nodes[index], context)
      when Range
        NodeSet.new(nodes[index], context)
      end
    end

    def first
      Node.wrap(nodes.first, context)
    end

    def last
      Node.wrap(nodes.last, context)
    end

    def empty?
      nodes.empty?
    end

    def size
      nodes.size
    end
    alias length size

    def to_a
      map { |node| node }
    end

    def +(other)
      self.class.new(nodes + other.nodes, context)
    end

    def ==(other)
      self.class == other.class &&
        length == other.length &&
        nodes.each_with_index.all? do |node, index|
          Node.wrap(node, context) == other[index]
        end
    end

    def text
      map(&:text).join
    end

    def remove
      each(&:remove)
      self
    end
  end
end
