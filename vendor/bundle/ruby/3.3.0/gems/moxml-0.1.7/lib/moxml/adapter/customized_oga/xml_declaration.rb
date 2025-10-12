# frozen_string_literal: true

require "oga"

module Moxml
  module Adapter
    module CustomizedOga
      class XmlDeclaration < ::Oga::XML::XmlDeclaration
        def initialize(options = {})
          @version    = options[:version] || "1.0"
          # encoding is optional, but Oga sets it to UTF-8 by default
          @encoding   = options[:encoding]
          @standalone = options[:standalone]
        end
      end
    end
  end
end
