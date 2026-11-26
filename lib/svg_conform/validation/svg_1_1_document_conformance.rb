# frozen_string_literal: true

require "moxml"
require "leptris"

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
    # Library choice (see the validator spec for the probe results): leptris
    # validates the flat DTD offline once the DTD is flattened into an
    # internal subset, because leptris never loads external DTDs.
    class Svg11DocumentConformance
      SVG_NS = "http://www.w3.org/2000/svg"
      XLINK_NS = "http://www.w3.org/1999/xlink"
      XML_NS = "http://www.w3.org/XML/1998/namespace"
      DATA_DIR = File.expand_path("../../../data/svg_1_1", __dir__)
      DTD_PATH = File.join(DATA_DIR, "svg11-flat-20110816.dtd")
      MANIFEST_PATH = File.join(DATA_DIR, "manifest.yml")
      EXTERNAL_ENTITY = /<!ENTITY\s+(?:%\s+)?[^\s>]+\s+(?:SYSTEM|PUBLIC)\b/m

      PUBLIC_DOCTYPE_RE = /<!DOCTYPE[^>]*>/.freeze


      ELEMENT_DECL = /<!ELEMENT\s+([A-Za-z_:][A-Za-z0-9._:-]*)/.freeze
      ATTLIST_DECL = /<!ATTLIST\s+([A-Za-z_:][A-Za-z0-9._:-]*)(.*?)>/m.freeze
      ATTR_DECL = /([A-Za-z_:][A-Za-z0-9._:-]*)\s+(?:CDATA|ID|IDREF|IDREFS|ENTITY|ENTITIES|NMTOKEN|NMTOKENS|NOTATION|\()/m.freeze


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

        copy = transform(parsed, xml_decl_version(source))
        return failure(:no_svg_root, "document element is not an SVG element") unless copy

        Result.new(issues: dtd_issues(copy), transformed: copy)
      end

      # Appendix G.2: drop foreign subtrees and attributes, drop prefixes,
      # keep xlink attributes under the xlink prefix, and set the two
      # namespace declarations on the document element. Returns the serialized
      # copy (with the DOCTYPE for the local DTD) or nil without an SVG root.
      def transform(doc, decl_version = "1.0")
        root = doc.root
        return unless root&.namespace&.uri == SVG_NS

        body = +""
        write_element(root, body, root: true)
        %(<?xml version="#{decl_version}" encoding="UTF-8"?>\n) +
          %(<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "#{dtd_uri}">\n#{body}\n)
      end

      private

      XML_DECL_VERSION = /\A\s*<\?xml[^?]*\bversion\s*=\s*["']([^"']+)["']/.freeze

      # Moxml documents do not expose the XML declaration; read it from the
      # source text.
      def xml_decl_version(source)
        source.match(XML_DECL_VERSION)&.captures&.first || "1.0"
      end

      # A file URI that libxml2 accepts for POSIX paths and for Windows drive
      # paths ("D:\\a\\x" becomes "file:///D:/a/x").
      def dtd_uri
        path = @dtd_path.tr("\\", "/")
        path = "/#{path}" unless path.start_with?("/")
        escaped = path.gsub(%r{[^A-Za-z0-9\-._~/:]}) { |char| char.bytes.map { |b| format("%%%02X", b) }.join }
        "file://#{escaped}"
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
        Moxml.parse(source)
      rescue Moxml::ParseError => e
        failure(:malformed_xml, e.message, e.line)
      end

      def write_element(node, out, root: false)
        out << "<" << node.name
        if root
          out << %( xmlns="#{SVG_NS}" xmlns:xlink="#{XLINK_NS}")
        end
        node.attributes.each { |attr| write_attribute(attr, out) }
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
        href = attr.namespace&.uri
        name = case href
               when nil then attr.name
               when XLINK_NS then "xlink:#{attr.name}"
               when XML_NS then "xml:#{attr.name}"
               end
        out << " " << name << %(="#{escape_attribute(attr.value)}") if name
      end

      def write_node(node, out)
        case node.node_type
        when :element
          write_element(node, out) if node.namespace&.uri == SVG_NS
        when :text, :cdata
          out << escape_text(node.content)
        when :comment
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

      # leptris never loads external DTDs, so the flat DTD cannot be applied
      # through the DOCTYPE the transform emits. For validation only, the
      # vendored DTD is flattened into an internal subset: parameter entities
      # are expanded textually and conditional sections resolved, because
      # libxml2 permits neither PE references nor conditional sections in an
      # internal subset and silently drops the whole subset otherwise.
      #
      # leptris also does not flag undeclared elements and attributes, so the
      # same flattened DTD is scanned for its ELEMENT and ATTLIST
      # declarations to reproduce those checks offline. Messages keep the
      # libxml2 wording the validator contract is written against.
      def dtd_issues(copy)
        validation_source = copy.sub(PUBLIC_DOCTYPE_RE, inline_doctype)
        doc = Leptris::XML.parse(validation_source)
        issues = Leptris::XML::DTD.from_document(doc).validate(doc)
          .map { |error| normalize_dtd_error(error) }
        issues.concat(declaration_issues(Moxml.parse(validation_source)))
        issues.map { |issue| Issue.new(kind: :dtd, message: issue[:message], line: issue[:line]) }
      rescue Leptris::XML::Error, Moxml::ParseError => e
        [Issue.new(kind: :dtd, message: e.message, line: nil)]
      end

      def normalize_dtd_error(error)
        message = error[:message].to_s.sub(/\A\d+:\d+: ERROR: /, "")
        message = case message
                  when /\AElement '([^']+)' missing #REQUIRED attribute '([^']+)'\z/
                    "Element #{Regexp.last_match(1)} does not carry attribute #{Regexp.last_match(2)}"
                  when /\AElement '([^']+)' content model requires (.+)\z/m
                    "Element #{Regexp.last_match(1)} content does not follow the DTD, " \
                      "expecting #{Regexp.last_match(2)}"
                  else
                    message
                  end
        { message: message, line: error[:line] }
      end

      def declaration_issues(doc)
        issues = []
        doc.traverse do |node|
          next unless node.node_type == :element

          name = node.name
          unless declared_elements.include?(name)
            issues << { message: "No declaration for element #{name}", line: node.line_number }
          end
          node.attributes.each do |attr|
            key = prefixed_attribute_name(attr)
            next if key.start_with?("xmlns")
            next if declared_attributes[name]&.include?(key)

            issues << { message: "No declaration for attribute #{key} on element #{name}",
                        line: node.line_number }
          end
        end
        issues
      end

      def prefixed_attribute_name(attr)
        case attr.namespace&.uri
        when XLINK_NS then "xlink:#{attr.name}"
        when XML_NS then "xml:#{attr.name}"
        else attr.name
        end
      end

      def declared_elements
        @declared_elements ||= flattened_dtd.scan(ELEMENT_DECL).map(&:first).to_set
      end

      def declared_attributes
        @declared_attributes ||= flattened_dtd.scan(ATTLIST_DECL)
          .each_with_object({}) do |(element, body), map|
          map[element] = body.scan(ATTR_DECL).map(&:first).to_set
        end
      end

      def inline_doctype
        @inline_doctype ||= "<!DOCTYPE svg [#{flattened_dtd}]>"
      end

      def flattened_dtd
        @flattened_dtd ||= self.class.flatten_dtd(File.read(@dtd_path))
      end

      # A sequential DTD preprocessor. libxml2 expands a parameter-entity
      # reference to the definition in effect at the reference point, and the
      # flat DTD leans on that: attribute PEs are redeclared per module and
      # qname PEs are redeclared to literal element names after the modular
      # machinery. A batch expansion cannot reproduce it, so the text is
      # walked in order: PE declarations register and vanish, conditional
      # sections resolve to INCLUDE content or nothing, and every remaining
      # reference expands live. The result is an internal-subset-safe
      # declaration stream (no PE references, no conditional sections).
      def self.flatten_dtd(dtd_text)
        current = {}
        out = +""
        process_section(dtd_text, current, out)
        out
      end

      PE_TOKEN = %r{
        <!ENTITY\s+%\s+([A-Za-z0-9._-]+)\s+(["'])(.*?)\2\s*>
        |<!\[\s*(?:(INCLUDE|IGNORE)|%([A-Za-z0-9._-]+);?)\s*\[
        |%([A-Za-z0-9._-]+);
      }xm.freeze
      CONDITIONAL_BODY_OPEN = /<!\[\s*(?:(?:INCLUDE|IGNORE)|%[A-Za-z0-9._-]+;?)\s*\[/i.freeze
      MAX_PE_DEPTH = 50

      def self.process_section(text, current, out)
        pos = 0
        while (match = PE_TOKEN.match(text, pos))
          out << expand_refs(text[pos...match.begin(0)], current)
          if match[1]
            # libxml2 keeps the first declaration of a parameter entity and
            # ignores later duplicates.
            current[match[1]] ||= match[3]
            pos = match.end(0)
          elsif match[4] || match[5]
            keyword = expand_refs(match[4] || current[match[5]] || "", current)
              .to_s.strip.upcase
            body_start, body_end, pos = conditional_extent(text, match.end(0))
            process_section(text[body_start...body_end], current, out) if keyword == "INCLUDE"
          else
            out << expand_refs(match[0], current)
            pos = match.end(0)
          end
        end
        out << expand_refs(text[pos..], current)
      end

      # Offsets of one conditional section's body: [start, end, after_close],
      # honouring nested conditional sections.
      def self.conditional_extent(text, open_end)
        depth = 1
        pos = open_end
        while depth.positive?
          close = text.index("]]>", pos)
          raise ArgumentError, "unterminated conditional section" unless close

          inner = CONDITIONAL_BODY_OPEN.match(text, pos)
          if inner && inner.end(0) <= close + 3
            depth += 1
            pos = inner.end(0)
          else
            depth -= 1
            pos = close + 3
          end
        end
        [open_end, pos - 3, pos]
      end

      def self.expand_refs(text, current, depth = 0)
        raise ArgumentError, "parameter entity recursion too deep" if depth > MAX_PE_DEPTH

        text.gsub(/%([A-Za-z0-9._-]+);/) do
          value = current[Regexp.last_match(1)]
          value ? expand_refs(value, current, depth + 1) : Regexp.last_match(0)
        end
      end
    end
  end
end
