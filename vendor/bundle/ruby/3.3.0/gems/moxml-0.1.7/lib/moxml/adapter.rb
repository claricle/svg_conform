# frozen_string_literal: true

require_relative "adapter/base"

module Moxml
  module Adapter
    AVALIABLE_ADAPTERS = %i[nokogiri oga rexml ox].freeze

    class << self
      def load(name)
        require_adapter(name)
        const_get(name.to_s.capitalize)
      rescue LoadError => e
        raise LoadError, "Could not load #{name} adapter. Please ensure the #{name} gem is available: #{e.message}"
      end

      private

      def require_adapter(name)
        require "#{__dir__}/adapter/#{name}"
      rescue LoadError
        begin
          require name.to_s
          require "#{__dir__}/adapter/#{name}"
        rescue LoadError => e
          raise LoadError, "Failed to load #{name} adapter: #{e.message}"
        end
      end
    end
  end
end
