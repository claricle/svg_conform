# frozen_string_literal: true

require_relative "base_requirement"
require_relative "../references/reference_classifier"

module SvgConform
  module Requirements
    # Rejects references that need another document, a local file or the
    # network. Same-document fragments and self-contained image data URLs pass.
    #
    # Every reference goes through References::ReferenceClassifier; data URL
    # decoding lives on References::DataUriReference. DOM and SAX validation
    # share the same finding logic (#attribute_findings, #css_findings,
    # #source_findings).
    class ExternalReferencesRequirement < BaseRequirement
      ALLOWED_DATA_TYPES = %w[image/png image/jpeg image/svg+xml].freeze
      URL_ATTRIBUTES = %w[fill stroke filter clip-path mask marker-start
                          marker-mid marker-end cursor].freeze
      SVG_NAMESPACE_ROOT = "svg"
      CSS_REFERENCE = /
        (?<import>@import\s+)?url\(\s*(?<q>['"]?)(?<url>.*?)\k<q>\s*\)
        | @import\s+(?<iq>['"])(?<iurl>.*?)\k<iq>
      /mix
      STYLESHEET_PI = /<\?xml-stylesheet\s(?<body>.*?)\?>/mi
      EXTERNAL_DOCTYPE = /<!ENTITY|<!DOCTYPE[^>\[]*\b(?:SYSTEM|PUBLIC)\b/i

      attribute :type, :string,
                default: -> { "ExternalReferencesRequirement" }
      attribute :max_data_uri_depth, :integer, default: -> { 3 }

      yaml do
        map "id", to: :id
        map "description", to: :description
        map "type", to: :type
        map "citation_uri", to: :citation_uri
        map "citation_label", to: :citation_label
        map "max_data_uri_depth", to: :max_data_uri_depth
      end

      class State
        attr_accessor :style_elements

        def initialize
          @style_elements = []
        end
      end

      def needs_deferred_validation?
        true
      end

      def check(node, context)
        return unless element?(node)

        attrs = (node.attributes || []).to_h { |a| [a.name.to_s, a.value.to_s] }
        report_all(node, context, attribute_findings(node.name, attrs))
        return unless local_name(node.name) == "style"

        report_all(node, context, css_findings(node.text.to_s))
      end

      def collect_sax_data(element, context)
        attrs = element.raw_attributes.to_h { |k, v| [k.to_s, v.to_s] }
        report_all(element, context, attribute_findings(element.name, attrs))
        return unless local_name(element.name) == "style"

        context.state_for(self).style_elements << element
      end

      def validate_sax_complete(context)
        context.state_for(self).style_elements.each do |element|
          report_all(element, context, css_findings(element.text_content.to_s))
        end
      end

      def validate_source(source, context)
        return if source.nil?

        report_all(nil, context, source_findings(source.to_s))
      end

      # Reference findings for one element's attributes: [{attr:, value:, reason:}]
      def attribute_findings(element_name, attrs, depth: 0, seen: [])
        findings = []
        attrs.each do |name, value|
          local = local_name(name)
          if local == "href"
            findings.concat(reference_findings(value, element_name, local,
                                               depth, seen))
          elsif local == "style"
            findings.concat(css_findings(value, depth: depth, seen: seen,
                                                element_name: element_name))
          elsif URL_ATTRIBUTES.include?(local)
            findings.concat(css_findings(value, depth: depth, seen: seen,
                                                element_name: element_name,
                                                attribute_name: name,
                                                urls_only: true))
          end
        end
        findings
      end

      def css_findings(css, depth: 0, seen: [], element_name: "style",
                       attribute_name: "style", urls_only: false)
        text = css.gsub(%r{/\*.*?\*/}m, "")
        text.to_enum(:scan, CSS_REFERENCE).flat_map do
          m = Regexp.last_match
          url = m[:url] || m[:iurl]
          next [] if url.nil? || url.empty?
          next [] if urls_only && m[:import]

          attr = m[:import] || m[:iurl] ? "@import" : "url()"
          reference_findings(url.strip, element_name, "#{attribute_name} #{attr}",
                             depth, seen)
        end
      end

      def source_findings(source)
        source.to_enum(:scan, STYLESHEET_PI).flat_map do
          body = Regexp.last_match[:body]
          href = body[/\bhref\s*=\s*(?:"([^"]*)"|'([^']*)')/, 1] ||
            body[/\bhref\s*=\s*'([^']*)'/, 1]
          next [] if href.nil? || href.empty?

          reference_findings(href, "xml-stylesheet", "href", 0, [])
        end
      end

      private

      def reference_findings(value, element_name, attribute_name, depth, seen)
        reference = References::ReferenceClassifier.classify(
          value, element_name: element_name, attribute_name: attribute_name
        )
        return [] unless reference

        reason = rejection_reason(reference, depth, seen)
        return [] unless reason

        [{ attr: attribute_name, value: value,
           type: reference.class.name.split("::").last, reason: reason }]
      end

      def rejection_reason(reference, depth, seen)
        case reference
        when References::InternalFragmentReference then nil
        when References::DataUriReference then data_uri_reason(reference, depth,
                                                               seen)
        when References::UrnReference then "URN requires an external resource"
        when References::ExternalUrlReference
          "network resource is not allowed"
        else "reference requires another document or local file"
        end
      end

      def data_uri_reason(reference, depth, seen)
        type = reference.normalized_media_type
        unless ALLOWED_DATA_TYPES.include?(type)
          return "unsupported data URL media type '#{type}'"
        end

        return reference.decode_error if reference.decode_error

        if type == "image/svg+xml"
          svg_data_reason(reference.payload, depth, seen)
        elsif (error = reference.raster_error)
          "invalid #{type} payload: #{error}"
        end
      end

      def svg_data_reason(payload, depth, seen)
        if depth >= max_data_uri_depth
          return "SVG data URL nesting exceeds #{max_data_uri_depth}"
        end

        digest = payload.hash
        return "SVG data URL contains a reference cycle" if seen.include?(digest)

        text = payload.dup.force_encoding(Encoding::UTF_8)
        return "SVG data URL is not valid UTF-8" unless text.valid_encoding?
        if text.match?(EXTERNAL_DOCTYPE)
          return "SVG data URL declares external entities"
        end

        nested = nested_findings(text, depth + 1, seen + [digest])
        return nested if nested.is_a?(String)

        first = nested.first
        first && "nested #{first[:attr]} '#{truncate(first[:value])}': #{first[:reason]}"
      end

      # Returns findings, or a String reason when the SVG is not usable
      def nested_findings(text, depth, seen)
        document = Document.from_content(text)
        root = document.root
        unless root && local_name(root.name) == SVG_NAMESPACE_ROOT
          return "SVG data URL does not contain an svg document"
        end

        findings = source_findings(text)
        document.traverse do |node|
          next unless element?(node)

          attrs = (node.attributes || []).to_h { |a| [a.name.to_s, a.value.to_s] }
          findings.concat(attribute_findings(node.name, attrs, depth: depth,
                                                               seen: seen))
          if local_name(node.name) == "style"
            findings.concat(css_findings(node.text.to_s, depth: depth,
                                                         seen: seen))
          end
        end
        findings
      rescue StandardError
        "SVG data URL is not well-formed XML"
      end

      def report_all(node, context, findings)
        findings.each do |finding|
          context.add_error(
            requirement_id: id,
            message: "External reference not allowed in #{finding[:attr]}: " \
                     "'#{truncate(finding[:value])}' (#{finding[:reason]})",
            node: node,
            severity: :error,
            data: { citation: citation_uri, attribute: finding[:attr],
                    reference_type: finding[:type],
                    reason: finding[:reason] },
          )
        end
      end

      def truncate(value)
        value.length > 60 ? "#{value[0, 57]}..." : value
      end

      def local_name(name)
        name.to_s.split(":").last
      end
    end
  end
end
