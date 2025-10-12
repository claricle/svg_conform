# frozen_string_literal: true

module Moxml
  module Adapter
    module CustomizedOx
      class Attribute < ::Ox::Node
        attr_reader :name, :prefix

        def initialize(attr_name, value, parent = nil)
          self.name = attr_name
          @parent = parent
          super(value)
        end

        def name=(new_name)
          @prefix, new_name = new_name.to_s.split(":", 2) if new_name.to_s.include?(":")

          @name = new_name
        end

        def expanded_name
          [prefix, name].compact.join(":")
        end
      end
    end
  end
end
