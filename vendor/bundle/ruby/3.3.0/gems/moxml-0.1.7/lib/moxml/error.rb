# frozen_string_literal: true

module Moxml
  class Error < StandardError; end

  class ParseError < Error
    attr_reader :line, :column

    def initialize(message, line: nil, column: nil)
      @line = line
      @column = column
      super(message)
    end
  end

  class ValidationError < Error; end
  class XPathError < Error; end
  class NamespaceError < Error; end
  class AdapterError < Error; end
end
