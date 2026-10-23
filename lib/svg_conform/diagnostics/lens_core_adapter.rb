# frozen_string_literal: true

require "lens_core"

module SvgConform
  module Diagnostics
    # Raised when an issue's data holds a value that cannot be written as
    # JSON (for example an arbitrary Ruby object).
    class UnsupportedContextError < SvgConform::Error; end

    # Maps a ValidationResult onto one LensCore::Report.
    #
    #   errors          -> error,   kind: violation type, else "validation"
    #   validity_errors -> error,   kind: "validity"
    #   warnings        -> warning, kind: violation type, else "validation"
    #   infos           -> info,    kind: violation type, else "notice"
    #
    # Order within each channel follows the source collections; channels are
    # emitted in the order above.
    module LensCoreAdapter
      PRODUCER = "svg_conform"
      REMEDIATION_FIELDS = %i[fixable remediable remediation_type
                              remediation_confidence affects_content].freeze

      module_function

      # @param validation_result [SvgConform::ValidationResult]
      # @param filename [String, nil] overrides the document's file path
      # @param timestamp [Time, String, nil] caller supplied, never defaulted
      # @return [LensCore::Report]
      # @raise [UnsupportedContextError] for non-JSON issue data
      def call(validation_result, filename: nil, timestamp: nil)
        profile = validation_result.profile
        LensCore::Report.new(
          producer: LensCore::Producer.new(name: PRODUCER,
                                           version: SvgConform::VERSION),
          profile: LensCore::Profile.new(
            id: profile.name.to_s,
            citations: citations(profile.specification_uri,
                                 profile.specification_label),
          ),
          valid: validation_result.valid?,
          diagnostics: diagnostics(validation_result, profile),
          timestamp: timestamp,
          extensions: file_extension(validation_result, filename),
        )
      end

      def file_extension(result, filename)
        file = filename || result.document&.file_path
        file ? { "file" => file.to_s } : {}
      end

      def diagnostics(result, profile)
        [
          *convert(result.errors, "error", "validation", profile),
          *convert(result.validity_errors, "error", "validity", profile,
                   force_kind: true),
          *convert(result.warnings, "warning", "validation", profile),
          *convert(result.infos, "info", "notice", profile, remediation: false),
        ]
      end

      def convert(issues, severity, fallback_kind, profile, force_kind: false,
                  remediation: true)
        issues.map do |issue|
          kind = force_kind ? fallback_kind : kind_for(issue, fallback_kind)
          build(issue, severity, kind, profile, remediation)
        end
      end

      def build(issue, severity, kind, profile, remediation)
        requirement_id = issue.requirement_id
        LensCore::Diagnostic.new(
          severity: severity, kind: kind, requirement_id: requirement_id,
          message: issue.message.to_s,
          citations: issue_citations(issue, profile, requirement_id),
          remediation: (issue.suggested_action if remediation && issue.remediable?),
          context: context(issue, remediation),
          location: location(issue)
        )
      end

      def kind_for(issue, fallback)
        type = issue.violation_type
        return fallback if type.nil? || type.to_s.empty? ||
          type.to_s == "unknown_violation"

        type.to_s
      end

      # A requirement's own citation, else the one an issue carries in its
      # data (a requirement reporting several IDs, such as the processing
      # categories, cites per issue).
      def issue_citations(issue, profile, requirement_id)
        found = requirement_citations(profile, requirement_id)
        return found unless found.empty?

        data = issue.data
        uri = data.is_a?(Hash) ? (data[:citation] || data["citation"]) : nil
        citations(uri, nil)
      end

      def requirement_citations(profile, requirement_id)
        requirement = profile.get_requirement(requirement_id)
        return [] unless requirement

        citations(requirement.citation_uri, requirement.citation_label)
      end

      def citations(uri, label)
        return [] if uri.nil? || uri.to_s.empty?

        [LensCore::Citation.new(uri: uri.to_s, label: label&.to_s)]
      end

      def context(issue, remediation)
        context = {}
        element = issue.element_name
        context["element"] = element.to_s if element
        if remediation
          REMEDIATION_FIELDS.each do |field|
            context[field.to_s] = json_value(remediation_value(issue, field),
                                             field.to_s)
          end
        end
        data = issue.data
        unless data.nil? || (data.respond_to?(:empty?) && data.empty?)
          context["data"] = json_value(data, "data")
        end
        context
      end

      def remediation_value(issue, field)
        case field
        when :fixable then issue.fixable?
        when :remediable then issue.remediable?
        when :affects_content then issue.affects_content?
        else issue.public_send(field)
        end
      end

      def location(issue)
        node = issue.node
        line = issue.line
        column = issue.column
        path = node.respond_to?(:path_id) ? node.path_id : nil
        line = nil unless line.is_a?(Integer) && line >= 1
        column = nil unless column.is_a?(Integer) && column >= 1
        return nil if line.nil? && column.nil? && path.nil?

        LensCore::Location.xml(line: line, column: column, path: path)
      end

      # Deep copy into JSON primitives. Symbols become strings; anything else
      # that JSON cannot carry fails with a stable error naming the path.
      def json_value(value, path)
        case value
        when nil, true, false, Integer, String then value
        when Float then json_float(value, path)
        when Symbol then value.to_s
        when Array
          value.each_with_index.map { |v, i| json_value(v, "#{path}[#{i}]") }
        when Hash then json_hash(value, path)
        else
          raise UnsupportedContextError,
                "unsupported value of type #{value.class} at #{path}; " \
                "issue data must be JSON-safe"
        end
      end

      def json_float(value, path)
        return value if value.finite?

        raise UnsupportedContextError,
              "unsupported non-finite number at #{path}"
      end

      def json_hash(hash, path)
        hash.to_h do |key, v|
          unless key.is_a?(String) || key.is_a?(Symbol)
            raise UnsupportedContextError,
                  "unsupported key of type #{key.class} at #{path}"
          end
          [key.to_s, json_value(v, "#{path}.#{key}")]
        end
      end
    end
  end
end
