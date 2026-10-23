# frozen_string_literal: true

require_relative "css2_core_grammar"

module SvgConform
  module Validation
    # Finds the url() and @import references in CSS by tokenizing it, so that
    # identifier escapes (+u\72l(+, +@\69mport+) are decoded before the name is
    # compared and url-like text inside strings or comments is ignored.
    module CssReferences
      Reference = Struct.new(:url, :import)
      # A declared property (name) or a @keyframes rule (keyframes: true)
      Feature = Struct.new(:name, :keyframes) do
        def description
          keyframes ? "CSS rule '@#{name}'" : "CSS property '#{name}'"
        end
      end

      ESCAPE = /\\(?:(?<hex>\h{1,6})(?:\r\n|[ \t\r\n\f])?|(?<char>[^\n\r\f]))/m
      LINE_CONTINUATION = /\\(?:\r\n|[\n\r\f])/

      module_function

      # @return [Array<Reference>] in source order; +import+ is true for
      #   references that are the target of an @import rule
      def extract(css)
        tokens = Css2CoreGrammar.tokenize(css)
        references = []
        import_pending = false
        index = 0
        while index < tokens.size
          token = tokens[index]
          case token.type
          when :s then nil
          when :atkeyword
            import_pending = decode(token.value).casecmp?("@import")
          when :string
            references << Reference.new(unquote(token.value), true) if import_pending
            import_pending = false
          when :uri
            references << Reference.new(uri_value(token.value), import_pending)
            import_pending = false
          when :function
            if decode(token.value.chomp("(")).casecmp?("url")
              url, index = function_url(tokens, index + 1)
              references << Reference.new(url, import_pending)
            end
            import_pending = false
          else
            import_pending = false
          end
          index += 1
        end
        references.reject { |reference| reference.url.nil? || reference.url.empty? }
      end

      # Property names declared in +css+ (a style attribute or style sheet),
      # plus @keyframes rules, with escapes decoded.
      # @return [Array<Feature>]
      def declarations(css)
        tokens = Css2CoreGrammar.tokenize(css).reject { |token| token.type == :s }
        tokens.each_with_index.filter_map do |token, index|
          if token.type == :atkeyword
            keyframes_feature(token)
          elsif property_at?(tokens, index)
            Feature.new(decode(token.value), false)
          end
        end
      end

      # An identifier followed by ":" that starts a declaration
      def property_at?(tokens, index)
        return false unless tokens[index].type == :ident && tokens[index + 1]&.type == ":"

        index.zero? || ["{", ";"].include?(tokens[index - 1].value)
      end

      def keyframes_feature(token)
        name = decode(token.value).delete_prefix("@")
        return unless name.downcase.sub(/\A-[a-z]+-/, "") == "keyframes"

        Feature.new(name, true)
      end

      def decode(text)
        text.gsub(LINE_CONTINUATION, "").gsub(ESCAPE) do
          match = Regexp.last_match
          match[:hex] ? codepoint(match[:hex].hex) : match[:char]
        end
      end

      def codepoint(number)
        return "�" if number.zero? || number > 0x10FFFF || number.between?(0xD800, 0xDFFF)

        [number].pack("U")
      end

      def unquote(string)
        decode(string[1..].chomp(string[0]))
      end

      def uri_value(token)
        inner = token.sub(/\Aurl\(/i, "").delete_suffix(")").strip
        inner.start_with?('"', "'") ? unquote(inner) : decode(inner)
      end

      # Tokens after an escaped "url(" up to the closing parenthesis.
      # @return [Array(String, Integer)] the url and the index of its last token
      def function_url(tokens, index)
        index += 1 while tokens[index]&.type == :s
        return [unquote(tokens[index].value), index] if tokens[index]&.type == :string

        parts = []
        while (token = tokens[index]) && token.value != ")"
          parts << token.value unless token.type == :s
          index += 1
        end
        [decode(parts.join), index]
      end
    end
  end
end
