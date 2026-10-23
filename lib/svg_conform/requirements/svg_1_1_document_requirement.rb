# frozen_string_literal: true

require "nokogiri"
require "strscan"
require_relative "base_requirement"
require_relative "../validation/svg_1_1_document_conformance"
require_relative "../validation/css2_core_grammar"

module SvgConform
  module Requirements
    # Source-level document checks for SVG 1.1 Full. One profile entry runs
    # one +rule+ (xml, root, version, grammar, css2 or xml_stylesheet), so each
    # carries its own ID and citation. All rules work from the original
    # source text through #validate_source, which both DOM and SAX
    # validation invoke exactly once; the element callbacks do nothing.
    class Svg11DocumentRequirement < BaseRequirement
      RULES = %w[xml root version grammar css2 xml_stylesheet].freeze
      SVG_NS = Validation::Svg11DocumentConformance::SVG_NS
      STYLESHEET_TARGET = "xml-stylesheet"
      PSEUDO_ATTRIBUTES = %w[href type title media charset alternate].freeze
      PSEUDO_ATTRIBUTE_PAIR = /\G\s*([^\s=]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/
      GRAMMAR_SKIPPED = %i[malformed_xml no_svg_root].freeze

      # Per-validation cache shared by every rule entry of a profile
      class State
        attr_accessor :parsed, :conformance

        def initialize
          @parsed = nil
          @conformance = nil
        end
      end

      attribute :type, :string, default: -> { "Svg11DocumentRequirement" }
      attribute :rule, :string

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "citation_uri", to: :citation_uri
        map "citation_label", to: :citation_label
        map "type", to: :type
        map "rule", to: :rule
      end

      def validate_source(source, context)
        return if source.nil?
        unless RULES.include?(rule)
          raise ArgumentError,
                "Svg11DocumentRequirement #{id}: unknown rule #{rule.inspect}"
        end

        send(:"check_#{rule}", source.to_s, context)
      end

      def validate_document(_document, _context); end

      def check(_node, _context); end

      private

      def check_xml(source, context)
        if context.source_serialized?
          return fail_with(context, "source was re-serialized from a parsed " \
                                    "tree; its XML declaration, doctype and " \
                                    "processing instructions cannot be proved")
        end

        parsed = parse(source, context)
        return unless parsed.is_a?(Hash) && parsed[:error]

        fail_with(context, "document is not well-formed XML: #{parsed[:error].message}",
                  line: parsed[:error].line)
      end

      def check_root(source, context)
        root = root_of(source, context)
        return unless root
        return if root.name == "svg" && root.namespace&.href == SVG_NS

        fail_with(context, "document element must be 'svg' in the " \
                           "#{SVG_NS} namespace, found " \
                           "'#{root.name}' in '#{root.namespace&.href}'")
      end

      def check_version(source, context)
        root = root_of(source, context)
        return unless root

        value = root["version"]
        return if value == "1.1"

        fail_with(context, value ? "root version must be \"1.1\", found #{value.inspect}" : "root element does not declare version=\"1.1\"")
      end

      def check_grammar(source, context)
        result = conformance(source, context)
        result.issues.each do |issue|
          next if GRAMMAR_SKIPPED.include?(issue.kind)

          fail_with(context, "SVG 1.1 DTD (#{issue.kind}): #{issue.message}",
                    line: issue.line)
        end
      end

      def check_css2(source, context)
        parsed = parse(source, context)
        return unless parsed.is_a?(Nokogiri::XML::Document)

        parsed.traverse do |node|
          next unless node.element? && node.namespace&.href == SVG_NS

          check_style_attribute(node, context)
          check_style_element(node, context)
        end
      end

      def check_xml_stylesheet(source, context)
        parsed = parse(source, context)
        return unless parsed.is_a?(Nokogiri::XML::Document)

        parsed.children.each do |node|
          next unless node.processing_instruction? && node.name == STYLESHEET_TARGET

          stylesheet_problems(node.content).each do |problem|
            fail_with(context, "xml-stylesheet: #{problem}", line: node.line)
          end
        end
      end

      def check_style_attribute(node, context)
        value = node["style"]
        return unless value

        report_css(Validation::Css2CoreGrammar.parse_declarations(value),
                   "style attribute on '#{node.name}'", node, context)
      end

      def check_style_element(node, context)
        return unless node.name == "style"
        return unless ["", "text/css"].include?(node["type"].to_s)

        report_css(Validation::Css2CoreGrammar.parse_stylesheet(node.content),
                   "style element", node, context)
      end

      def report_css(result, where, node, context)
        result.errors.each do |error|
          fail_with(context, "CSS 2 grammar in #{where}: #{error}",
                    line: node.line)
        end
      end

      # Pseudo-attribute syntax of the xml-stylesheet Recommendation plus the
      # SVG applicability rule that a declared type must be CSS.
      def stylesheet_problems(content)
        problems = []
        pairs = []
        scanner = StringScanner.new(content)
        until scanner.eos?
          unless scanner.scan(PSEUDO_ATTRIBUTE_PAIR)
            problems << "malformed pseudo-attribute near #{scanner.rest.strip[0, 20].inspect}"
            break
          end
          pairs << [scanner[1], scanner[2] || scanner[3]]
        end
        names = pairs.map(&:first)
        problems << "duplicate pseudo-attribute #{names.tally.select { |_, n| n > 1 }.keys.first}" if names.uniq.size != names.size
        names.reject { |n| PSEUDO_ATTRIBUTES.include?(n) }.each do |name|
          problems << "unknown pseudo-attribute '#{name}'"
        end
        values = pairs.to_h
        problems << "href pseudo-attribute is required" if problems.empty? && values["href"].to_s.empty?
        if values["type"] && values["type"] != "text/css"
          problems << "type #{values['type'].inspect} is not applicable to SVG (text/css expected)"
        end
        if values["alternate"] && !%w[yes no].include?(values["alternate"])
          problems << "alternate must be \"yes\" or \"no\""
        end
        problems
      end

      def conformance(source, context)
        state = context.state_for(self)
        state.conformance ||= Validation::Svg11DocumentConformance.new.validate(source)
      end

      # Non-validating, offline parse; a Hash with :error when malformed.
      def parse(source, context)
        state = context.state_for(self)
        state.parsed ||= begin
          doc = Nokogiri::XML::Document.parse(source) { |c| c.strict.nonet }
          doc.root ? doc : { error: Nokogiri::XML::SyntaxError.new("document has no root element") }
        rescue Nokogiri::XML::SyntaxError => e
          { error: e }
        end
      end

      def root_of(source, context)
        parsed = parse(source, context)
        parsed.is_a?(Nokogiri::XML::Document) ? parsed.root : nil
      end

      def fail_with(context, message, line: nil)
        data = { citation: citation_uri }
        data[:line] = line if line.is_a?(Integer) && line.positive?
        context.add_error(requirement_id: id, message: message, node: nil,
                          severity: :error, data: data)
      end
    end
  end
end
