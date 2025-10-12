# frozen_string_literal: true

module Moxml
  class Comment < Node
    def content
      adapter.comment_content(@native)
    end

    def content=(text)
      text = normalize_xml_value(text)
      adapter.validate_comment_content(text)
      adapter.set_comment_content(@native, text)
    end
  end
end
