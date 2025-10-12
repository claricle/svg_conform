# frozen_string_literal: true

module Moxml
  class Cdata < Node
    def content
      adapter.cdata_content(@native)
    end

    def content=(text)
      adapter.set_cdata_content(@native, normalize_xml_value(text))
    end
  end
end
