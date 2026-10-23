# frozen_string_literal: true

require "strscan"

module SvgConform
  module Validation
    # Syntax-only tokenizer and parser for the CSS 2 core grammar that SVG 1.1
    # requires (https://www.w3.org/TR/2008/REC-CSS2-20080411/grammar.html).
    #
    # It checks tokens, block nesting, rulesets and declarations. It does not
    # know property names, value semantics or rendering. Pure Ruby; no I/O.
    module Css2CoreGrammar
      Token = Struct.new(:type, :value, :line, :column)
      Error = Struct.new(:message, :line, :column) do
        def to_s
          "#{message} (line #{line}, column #{column})"
        end
      end

      # Outcome of a parse: +errors+ is empty when the input is valid.
      class Result
        attr_reader :errors

        def initialize(errors)
          @errors = errors.freeze
        end

        def valid?
          errors.empty?
        end
      end

      NONASCII = '[^\x00-\x7F]'
      UNICODE = '\\\\[0-9a-fA-F]{1,6}(?:\r\n|[ \n\r\t\f])?'
      ESCAPE = "(?:#{UNICODE}|\\\\[^\\n\\r\\f0-9a-fA-F])".freeze
      NMSTART = "(?:[_a-zA-Z]|#{NONASCII}|#{ESCAPE})".freeze
      NMCHAR = "(?:[_a-zA-Z0-9-]|#{NONASCII}|#{ESCAPE})".freeze
      IDENT_SRC = "-?#{NMSTART}#{NMCHAR}*".freeze
      NUM_SRC = '(?:[0-9]+|[0-9]*\.[0-9]+)'
      NL = '(?:\n|\r\n|\r|\f)'
      STRING_BODY = lambda do |quote|
        "#{quote}(?:[^\\n\\r\\f\\\\#{quote}]|\\\\#{NL}|#{ESCAPE})*"
      end

      IDENT = /#{IDENT_SRC}/o
      PATTERNS = [
        [:s, /[ \t\r\n\f]+/],
        [:comment, %r{/\*[^*]*\*+(?:[^/*][^*]*\*+)*/}],
        [:cdo, /<!--/],
        [:cdc, /-->/],
        [:includes, /~=/],
        [:dashmatch, /\|=/],
        [:string, /#{STRING_BODY.call('"')}"|#{STRING_BODY.call("'")}'/],
        [:bad_string, /#{STRING_BODY.call('"')}|#{STRING_BODY.call("'")}/],
        [:hash, /\##{NMCHAR}+/o],
        [:atkeyword, /@#{IDENT_SRC}/o],
        [:uri, /url\([ \t\r\n\f]*(?:#{STRING_BODY.call('"')}"|#{STRING_BODY.call("'")}'|(?:[!#$%&*-~]|#{NONASCII}|#{ESCAPE})*)[ \t\r\n\f]*\)/io],
        [:unicode_range, /u\+[0-9a-f?]{1,6}(?:-[0-9a-f]{1,6})?/i],
        [:function, /#{IDENT_SRC}\(/o],
        [:dimension, /#{NUM_SRC}#{IDENT_SRC}/o],
        [:percentage, /#{NUM_SRC}%/],
        [:number, /#{NUM_SRC}/],
        [:ident, /#{IDENT_SRC}/o],
      ].freeze

      # Characters that are their own token types.
      PUNCTUATION = %w[; { } ( ) [ ] :].freeze
      ANY_TYPES = %i[ident number percentage dimension string delim uri hash
                     unicode_range includes dashmatch].freeze
      SKIPPED_TOP_LEVEL = %i[s cdo cdc].freeze
      CLOSERS = { "(" => ")", "[" => "]" }.freeze

      module_function

      # Tokenize CSS text. Comments are dropped; unterminated comments and
      # strings surface as :bad_comment / :bad_string tokens.
      # @return [Array<Token>]
      def tokenize(text)
        scanner = StringScanner.new(text.to_s)
        tokens = []
        line = 1
        line_start = 0
        until scanner.eos?
          pos = scanner.pos
          type, value = next_token(scanner)
          column = pos - line_start + 1
          tokens << Token.new(type, value, line, column) unless type == :comment
          value.scan(/\r\n|[\n\r\f]/) { line += 1 }
          nl = value.rindex(/[\n\r\f]/)
          line_start = pos + nl + 1 if nl
        end
        tokens
      end

      # Parse a style sheet (style element content or external sheet).
      # @return [Result]
      def parse_stylesheet(text)
        Parser.new(tokenize(text)).stylesheet
      end

      # Parse the content of a style attribute: a declaration list without
      # braces.
      # @return [Result]
      def parse_declarations(text)
        Parser.new(tokenize(text)).declaration_list
      end

      def next_token(scanner)
        PATTERNS.each do |type, regex|
          value = scanner.scan(regex)
          return [type, value] if value
        end
        return [:bad_comment, scanner.scan(%r{/\*.*}m)] if scanner.check(%r{/\*})

        char = scanner.getch
        [PUNCTUATION.include?(char) ? char : :delim, char]
      end
      private_class_method :next_token

      # Recursive-descent parser over the token list (CSS 2.1 Appendix G.1).
      class Parser
        def initialize(tokens)
          @tokens = tokens
          @pos = 0
          @errors = []
        end

        def stylesheet
          until eof?
            token = peek
            if SKIPPED_TOP_LEVEL.include?(token.type)
              advance
            else
              statement
            end
          end
          Result.new(@errors)
        end

        def declaration_list
          skip_space
          declarations_until(nil)
          Result.new(@errors)
        end

        private

        def eof?
          @pos >= @tokens.length
        end

        def peek
          @tokens[@pos]
        end

        def advance
          token = @tokens[@pos]
          @pos += 1
          token
        end

        def skip_space
          advance while !eof? && peek.type == :s
        end

        def type?(type)
          !eof? && peek.type == type
        end

        def error(message, token = peek || @tokens.last)
          @errors << Error.new(message, token&.line || 1, token&.column || 1)
        end

        def statement
          if type?(:atkeyword)
            at_rule
          else
            ruleset
          end
        end

        def at_rule
          advance
          skip_space
          until eof? || type?("{") || type?(";")
            break unless any?
          end
          if type?("{")
            block
          elsif type?(";")
            advance
          else
            error("at-rule is missing ';' or a block")
          end
          skip_space
        end

        # selector? '{' declarations '}'
        def ruleset
          start = peek
          until eof? || type?("{")
            unless any?
              error("unexpected #{describe(peek)} in selector")
              advance
            end
          end
          return error("selector is missing a '{' block", start) if eof?

          advance
          skip_space
          declarations_until("}")
          if type?("}")
            advance
          else
            error("ruleset is missing '}'", start)
          end
          skip_space
        end

        def declarations_until(closer)
          loop do
            skip_space
            break if eof? || (closer && type?(closer))

            if type?(";")
              advance
              next
            end
            declaration(closer)
            skip_space
            break if eof? || (closer && type?(closer))

            if type?(";")
              advance
            else
              error("expected ';' after declaration, found #{describe(peek)}")
              recover(closer)
            end
          end
        end

        # property ':' S* value
        def declaration(closer)
          unless type?(:ident)
            error("expected a property name, found #{describe(peek)}")
            return recover(closer)
          end
          advance
          skip_space
          unless type?(":")
            error("expected ':' after property name")
            return recover(closer)
          end
          advance
          skip_space
          value(closer)
        end

        def value(closer)
          first = peek
          count = 0
          until eof? || type?(";") || (closer && type?(closer))
            if type?("{")
              block
            elsif type?(:atkeyword)
              advance
              skip_space
            elsif !any?
              error("unexpected #{describe(peek)} in declaration value")
              advance
            end
            count += 1
          end
          error("declaration has no value", first) if count.zero?
        end

        # Skip to the next ';' or the closing delimiter.
        def recover(closer)
          advance until eof? || type?(";") || (closer && type?(closer))
        end

        # '{' S* [any | block | ATKEYWORD S* | ';' S*]* '}' S*
        def block
          open = advance
          skip_space
          loop do
            if eof?
              error("block opened here is missing '}'", open)
              return
            end
            break if type?("}")

            if type?("{")
              block
            elsif type?(:atkeyword) || type?(";")
              advance
              skip_space
            elsif !any?
              error("unexpected #{describe(peek)} in block")
              advance
            end
          end
          advance
          skip_space
        end

        # Consumes one `any` production (plus trailing space). Returns false
        # without consuming when the next token is not an `any` start.
        def any?
          return false if eof?

          token = peek
          if ANY_TYPES.include?(token.type) || token.type == ":"
            advance
          elsif token.type == :function
            advance
            skip_space
            group(")", token)
          elsif CLOSERS.key?(token.type)
            advance
            skip_space
            group(CLOSERS[token.type], token)
          elsif token.type == :bad_string
            error("unterminated string", token)
            advance
          elsif token.type == :bad_comment
            error("unterminated comment", token)
            advance
          else
            return false
          end
          skip_space
          true
        end

        def group(closer, opener)
          loop do
            if eof?
              error("'#{opener.value}' is missing '#{closer}'", opener)
              return
            end
            break if type?(closer)
            next if any?

            error("unexpected #{describe(peek)} inside '#{opener.value}'")
            advance
          end
          advance
        end

        def describe(token)
          return "end of input" unless token

          "'#{token.value.to_s.strip[0, 20]}'"
        end
      end
    end
  end
end
