# frozen_string_literal: true

module Moxml
  class Text < Node
    def content
      adapter.text_content(@native)
    end

    def content=(text)
      adapter.set_text_content(@native, normalize_xml_value(text))
    end
  end
end
