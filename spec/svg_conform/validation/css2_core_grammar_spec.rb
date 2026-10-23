# frozen_string_literal: true

require "spec_helper"
require "svg_conform/validation/css2_core_grammar"

RSpec.describe SvgConform::Validation::Css2CoreGrammar do
  describe ".tokenize" do
    def types(css)
      described_class.tokenize(css).map(&:type)
    end

    it "classifies the CSS 2 token kinds" do
      css = 'a:hover #id 10 50% 2em url(x.png) rgb( "s" U+0-7F ~= |= @page <!-- -->'
      expect(types(css).reject { |t| t == :s }).to eq(
        [:ident, ":", :ident, :hash, :number, :percentage, :dimension, :uri, :function, :string,
         :unicode_range, :includes, :dashmatch, :atkeyword, :cdo, :cdc],
      )
    end

    it "drops comments and tracks line and column" do
      tokens = described_class.tokenize("a /* c\n */ b")
      expect(tokens.map(&:value)).to eq(["a", " ", " ", "b"])
      expect(tokens.last.line).to eq(2)
      expect(tokens.last.column).to eq(5)
    end

    it "flags unterminated strings and comments" do
      expect(types('"abc')).to eq([:bad_string])
      expect(types("/* abc")).to eq([:bad_comment])
    end

    it "accepts escapes in identifiers" do
      expect(types('\66 ill')).to eq([:ident])
    end
  end

  describe ".parse_stylesheet" do
    valid = {
      "empty sheet" => "",
      "comments and CDO/CDC" => "<!-- /* x */ a { fill: red } -->",
      "multiple selectors" => "rect, circle.a > path[x=\"1\"]:first-child { fill: #fff }",
      "empty declaration slots" => "a { ; fill: red;; stroke: blue; }",
      "functions and !important" => "a { fill: rgb(1, 2, 3) !important; stroke: url(#g) }",
      "empty ruleset" => "a { }",
      "@import" => '@import url("x.css") screen;',
      "@media with nested rules" => "@media print { a { x: y } b { x: y } }",
      "@font-face" => '@font-face { font-family: "F"; src: url(f.woff) }',
      "unknown at-rule block" => "@foo bar { baz { qux: 1 } }",
      "selector-less ruleset" => "{ fill: red }",
    }

    valid.each do |name, css|
      it "accepts #{name}" do
        expect(described_class.parse_stylesheet(css)).to be_valid
      end
    end

    invalid = {
      "missing colon" => ["a { fill red }", /expected ':'/],
      "missing value" => ["a { fill: }", /no value/],
      "missing property" => ["a { : red }", /property name/],
      "unclosed ruleset" => ["a { fill: red", /missing '}'/],
      "unclosed string" => ["a { fill: \"red }", /unterminated string/],
      "unclosed comment" => ["a { fill: red } /* x", /unterminated comment/],
      "unclosed function" => ["a { fill: rgb(1,2 }", /missing '\)'/],
      "selector without block" => ["a b", /missing a '\{' block/],
      "unterminated at-rule" => ["@import url(x.css)", /at-rule/],
      "stray closing brace" => ["a { fill: red } }", /unexpected '\}'/],
    }

    invalid.each do |name, (css, message)|
      it "rejects #{name}" do
        result = described_class.parse_stylesheet(css)
        expect(result).not_to be_valid
        expect(result.errors.map(&:message).join("\n")).to match(message)
      end
    end

    it "reports the position of the first error" do
      error = described_class.parse_stylesheet("a { fill: red }\nb { fill blue }")
        .errors.first
      expect(error.line).to eq(2)
      expect(error.to_s).to include("line 2")
    end
  end

  describe ".parse_declarations" do
    it "accepts a style attribute value" do
      css = "fill:red; stroke : url(#a) ; stroke-width:2px;"
      expect(described_class.parse_declarations(css)).to be_valid
    end

    it "accepts an empty value and stray semicolons" do
      expect(described_class.parse_declarations("")).to be_valid
      expect(described_class.parse_declarations(" ; ;")).to be_valid
    end

    it "rejects a declaration without a colon" do
      result = described_class.parse_declarations("fill red")
      expect(result).not_to be_valid
    end

    it "rejects a stray closing brace in a declaration list" do
      result = described_class.parse_declarations("fill:red } stroke:blue")
      expect(result).not_to be_valid
    end

    it "rejects a ruleset where a declaration list is expected" do
      expect(described_class.parse_declarations("a { fill: red }")).not_to be_valid
    end

    it "does not judge property names or values" do
      expect(described_class.parse_declarations("bogus-prop: nonsense 12qq")).to be_valid
    end
  end
end
