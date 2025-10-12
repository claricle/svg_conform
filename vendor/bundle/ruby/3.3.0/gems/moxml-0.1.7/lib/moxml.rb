# frozen_string_literal: true

module Moxml
  class << self
    def new(adapter = nil, &block)
      context = Context.new(adapter)
      context.config.instance_eval(&block) if block_given?
      context
    end

    def configure
      yield Config.default if block_given?
    end

    def with_config(adapter_name = nil, strict_parsing = nil, default_encoding = nil)
      original_config = Config.default.dup

      configure do |config|
        config.adapter = adapter_name unless adapter_name.nil?
        config.strict_parsing = strict_parsing unless strict_parsing.nil?
        config.default_encoding = default_encoding unless default_encoding.nil?
      end

      yield if block_given?

      # restore the original config
      configure do |config|
        config.adapter = original_config.adapter_name
        config.strict_parsing = original_config.strict_parsing
        config.default_encoding = original_config.default_encoding
      end
      original_config = nil
    end
  end
end

require_relative "moxml/version"
require_relative "moxml/document"
require_relative "moxml/document_builder"
require_relative "moxml/error"
require_relative "moxml/builder"
require_relative "moxml/config"
require_relative "moxml/context"
require_relative "moxml/adapter"
