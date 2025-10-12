# frozen_string_literal: true

module Moxml
  module Adapter
    module CustomizedOx
      # Ox uses Strings, but a string cannot have a parent reference
      class Text < ::Ox::Node; end
    end
  end
end
