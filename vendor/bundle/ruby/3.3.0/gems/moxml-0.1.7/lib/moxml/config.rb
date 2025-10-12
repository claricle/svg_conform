# frozen_string_literal: true

module Moxml
  class Config
    VALID_ADAPTERS = %i[nokogiri oga rexml ox].freeze
    DEFAULT_ADAPTER = VALID_ADAPTERS.first

    class << self
      attr_writer :default_adapter

      def default
        @default ||= new(default_adapter, true, "UTF-8")
      end

      def default_adapter
        @default_adapter ||= DEFAULT_ADAPTER
      end
    end

    attr_reader :adapter_name
    attr_accessor :strict_parsing,
                  :default_encoding,
                  :entity_encoding,
                  :default_indent

    def initialize(adapter_name = nil, strict_parsing = nil, default_encoding = nil)
      self.adapter = adapter_name || Config.default.adapter_name
      @strict_parsing = strict_parsing || Config.default.strict_parsing
      @default_encoding = default_encoding || Config.default.default_encoding
      # reserved for future use
      @default_indent = 2
      @entity_encoding = :basic
    end

    def adapter=(name)
      name = name.to_sym
      @adapter = nil

      unless VALID_ADAPTERS.include?(name)
        raise ArgumentError, "Invalid adapter: #{name}. Valid adapters are: #{VALID_ADAPTERS.join(", ")}"
      end

      @adapter_name = name
      adapter
    end

    def default_adapter=(name)
      self.adapter = name
      self.class.default_adapter = name
    end

    def adapter
      @adapter ||= Adapter.load(@adapter_name)
    end
  end
end
