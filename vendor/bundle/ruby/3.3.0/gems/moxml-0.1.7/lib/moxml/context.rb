# frozen_string_literal: true

module Moxml
  class Context
    attr_reader :config

    def initialize(adapter = nil)
      @config = Config.new(adapter)
    end

    def create_document(native_doc = nil)
      Document.new(config.adapter.create_document(native_doc), self)
    end

    def parse(xml, options = {})
      config.adapter.parse(xml, default_options.merge(options))
    end

    private

    def default_options
      {
        encoding: config.default_encoding,
        strict: config.strict_parsing,
        indent: config.default_indent
      }
    end
  end
end
