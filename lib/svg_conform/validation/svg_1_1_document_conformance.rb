# frozen_string_literal: true

require "nokogiri"
require "yaml"

module SvgConform
  module Validation
    # Validates an SVG 1.1 document against the vendored SVG 1.1 flat DTD,
    # following the validity procedure of SVG 1.1 Appendix G.2
    # (conform.html#ConformingSVGDocuments).
    #
    # The DTD is resolved from the local data/svg_1_1 directory only. The
    # caller's source is never modified: the Appendix G.2 transform is built
    # from a separate parse of it, and a document that declares an external
    # entity is rejected before any entity is expanded.
    #
    # Library choice (see the validator spec for the probe results): the
    # bundled Moxml/Leptris stack parses the flat DTD but does not apply its
    # conditional sections, so it accepts every document. Nokogiri (libxml2)
    # validates the flat DTD offline.
    class Svg11DocumentConformance
      SVG_NS = "http://www.w3.org/2000/svg"
      XLINK_NS = "http://www.w3.org/1999/xlink"
      XML_NS = "http://www.w3.org/XML/1998/namespace"
      DATA_DIR = File.expand_path("../../../data/svg_1_1", __dir__)
      DTD_PATH = File.join(DATA_DIR, "svg11-flat-20110816.dtd")
      MANIFEST_PATH = File.join(DATA_DIR, "manifest.yml")
      EXTERNAL_ENTITY = /<!ENTITY\s+(?:%\s+)?[^\s>]+\s+(?:SYSTEM|PUBLIC)\b/m

      Issue = Struct.new(:kind, :message, :line, keyword_init: true)

      # Outcome of one validation. +transformed+ is the Appendix G.2 copy
      # that was validated (nil when no copy could be built).
      Result = Struct.new(:issues, :transformed, keyword_init: true) do
        def valid?
          issues.empty?
        end
      end

      def initialize(dtd_path: DTD_PATH)
        @dtd_path = dtd_path
      end

      def validate(source)
        source = source.to_s
        return failure(:external_entity, "external entities are not permitted") if external_entity?(source)

        parsed = parse_expanded(source)
        return parsed if parsed.is_a?(Result)

        copy = transform(parsed)
        return failure(:no_svg_root, "document element is not an SVG element") unless copy

        Result.new(issues: dtd_issues(copy), transformed: copy)
      end

      # Appendix G.2: drop foreign subtrees and attributes, drop prefixes,
      # keep xlink attributes under the xlink prefix, and set the two
      # namespace declarations on the document element. Returns the serialized
      # copy (with the DOCTYPE for the local DTD) or nil without an SVG root.
      def transform(doc)
        root = doc.root
        return unless root&.namespace&.href == SVG_NS

        body = +""
        write_element(root, body, root: true)
        %(<?xml version="#{doc.version || '1.0'}" encoding="UTF-8"?>\n) +
          %(<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "#{dtd_uri}">\n#{body}\n)
      end

      private

      def dtd_uri
        "file://#{@dtd_path}"
      end

      def failure(kind, message, line = nil)
        Result.new(issues: [Issue.new(kind: kind, message: message, line: line)], transformed: nil)
      end

      def external_entity?(source)
        source.match?(EXTERNAL_ENTITY)
      end

      # Entities are expanded (Appendix G.2) only after the source is known
      # to declare no external entity, so expansion cannot read a file.
      def parse_expanded(source)
        Nokogiri::XML::Document.parse(source) { |config| config.strict.noent.nonet }
      rescue Nokogiri::XML::SyntaxError => e
        failure(:malformed_xml, e.message, e.line)
      end

      def write_element(node, out, root: false)
        out << "<" << node.name
        if root
          out << %( xmlns="#{SVG_NS}" xmlns:xlink="#{XLINK_NS}")
        end
        node.attribute_nodes.each { |attr| write_attribute(attr, out) }
        children = node.children
        if children.empty?
          out << "/>"
        else
          out << ">"
          children.each { |child| write_node(child, out) }
          out << "</" << node.name << ">"
        end
      end

      def write_attribute(attr, out)
        href = attr.namespace&.href
        name = case href
               when nil then attr.name
               when XLINK_NS then "xlink:#{attr.name}"
               when XML_NS then "xml:#{attr.name}"
               end
        out << " " << name << %(="#{escape_attribute(attr.value)}") if name
      end

      def write_node(node, out)
        case node.type
        when Nokogiri::XML::Node::ELEMENT_NODE
          write_element(node, out) if node.namespace&.href == SVG_NS
        when Nokogiri::XML::Node::TEXT_NODE, Nokogiri::XML::Node::CDATA_SECTION_NODE
          out << escape_text(node.content)
        when Nokogiri::XML::Node::COMMENT_NODE
          out << "<!--" << node.content << "-->"
        end
      end

      def escape_text(text)
        text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
      end

      def escape_attribute(text)
        escape_text(text).gsub('"', "&quot;").gsub("\t", "&#9;")
          .gsub("\n", "&#10;").gsub("\r", "&#13;")
      end

      def dtd_issues(copy)
        doc = Nokogiri::XML::Document.parse(copy) do |config|
          config.dtdload.dtdvalid.nonet
        end
        doc.errors.map do |error|
          Issue.new(kind: :dtd, message: error.message.sub(/\A\d+:\d+: ERROR: /, ""),
                    line: error.line)
        end
      end
    end
  end
end
