# frozen_string_literal: true

require_relative "base"

module SvgConform
  module Errors
    # Validation issue (error, warning, or notice)
    #
    # Represents a single validation issue found during SVG validation.
    # Contains information about the issue including type, rule, node,
    # message, fix, and remediation information.
    class ValidationIssue < Base
      attr_reader :rule, :fix, :data,
                  :requirement_id_override, :severity, :violation_type

      def initialize(type:, rule:, node:, message:, fix: nil, data: {},
requirement_id: nil, severity: nil, violation_type: nil)
        super(type: type, node: node, message: message)
        @rule = rule
        @fix = fix
        @data = data
        @requirement_id_override = requirement_id
        @severity = severity
        @violation_type = violation_type || detect_violation_type
      end

      def requirement_id
        return @requirement_id_override.to_s if @requirement_id_override

        if @rule.respond_to?(:id)
          @rule.id.to_s
        elsif @rule.respond_to?(:class) && @rule.class.respond_to?(:name)
          # Extract ID from class name for requirements
          class_name = @rule.class.name.split("::").last
          class_name.gsub(/Requirement$/, "").downcase.gsub(/([a-z])([A-Z])/,
                                                            '\1_\2').downcase
        else
          "unknown"
        end
      end

      def error?
        @type == :error
      end

      def warning?
        @type == :warning
      end

      def fixable?
        !@fix.nil?
      end

      def line
        @node.respond_to?(:line) ? @node.line : nil
      end

      def column
        @node.respond_to?(:column) ? @node.column : nil
      end

      def element_name
        @node.respond_to?(:name) ? @node.name : nil
      end

      def apply_fix
        return false unless fixable?

        begin
          if @fix.respond_to?(:call)
            @fix.call
          else
            @fix.apply
          end
          true
        rescue StandardError
          false
        end
      end

      # Check if this issue is remediable
      def remediable?
        case @violation_type
        when :color_violation, :font_violation, :content_violation, :reference_violation,
             :namespace_violation, :viewbox_violation, :style_violation
          true
        when :structural_violation
          false
        else
          # Default to remediable for backward compatibility
          true
        end
      end

      # Get the type of remediation needed
      def remediation_type
        case @violation_type
        when :color_violation, :font_violation
          :convert
        when :content_violation, :reference_violation, :namespace_violation
          :remove
        when :viewbox_violation
          :add
        when :style_violation
          :promote
        else
          :unknown
        end
      end

      # Get the confidence level of automated remediation
      def remediation_confidence
        case @violation_type
        when :color_violation, :font_violation, :style_violation
          :automatic
        when :viewbox_violation, :namespace_violation
          :safe_structural
        when :content_violation, :reference_violation
          :safe_removal
        else
          :manual_review
        end
      end

      # Get the suggested action to fix this issue
      def suggested_action
        case @violation_type
        when :color_violation
          "Convert color to allowed equivalent using CssColor"
        when :font_violation
          "Map font family to generic equivalent"
        when :content_violation
          "Remove forbidden element or attribute"
        when :reference_violation
          "Remove broken reference or containing element"
        when :namespace_violation
          "Fix namespace declarations and remove invalid elements/attributes"
        when :viewbox_violation
          "Add missing viewBox attribute"
        when :style_violation
          "Promote style properties to attributes"
        when :structural_violation
          "Manual fix required - document structure issue"
        else
          "Apply available remediation"
        end
      end

      # Check if this issue affects document content
      def affects_content?
        case @violation_type
        when :content_violation, :reference_violation
          true
        when :color_violation, :font_violation, :style_violation, :viewbox_violation, :namespace_violation
          false
        else
          false
        end
      end

      def to_h
        {
          type: @type,
          rule: rule_id,
          message: @message,
          line: line,
          column: column,
          element: element_name,
          fixable: fixable?,
          remediable: remediable?,
          violation_type: @violation_type,
          remediation_type: remediation_type,
          remediation_confidence: remediation_confidence,
          suggested_action: suggested_action,
          affects_content: affects_content?,
        }
      end

      def to_s
        location = line ? " at line #{line}" : ""
        location += ":#{column}" if column
        rule_info = rule_id ? " (#{rule_id})" : ""
        remediation_info = remediable? ? " [#{remediation_type}]" : " [NOT REMEDIABLE]"
        "#{@message}#{location}#{rule_info}#{remediation_info}"
      end

      private

      def detect_violation_type
        req_id = requirement_id.downcase
        msg = @message.downcase

        # First check for structural violations (non-remediable)
        return :structural_violation if msg.include?("root element must be") ||
          msg.include?("malformed") ||
          msg.include?("invalid document") ||
          msg.include?("required element missing") ||
          msg.include?("invalid hierarchy")

        # Then check requirement-based violations (remediable)
        case req_id
        when /color/
          :color_violation
        when /font/
          :font_violation
        when /forbidden|content/
          :content_violation
        when /reference|id/
          :reference_violation
        when /namespace/
          :namespace_violation
        when /viewbox/
          :viewbox_violation
        when /style/
          :style_violation
        else
          # Check message content for clues
          return :color_violation if msg.include?("color")
          return :font_violation if msg.include?("font")
          return :content_violation if msg.include?("forbidden")
          return :reference_violation if msg.include?("reference") || msg.include?("href")
          return :namespace_violation if msg.include?("namespace")
          return :viewbox_violation if msg.include?("viewbox")
          return :style_violation if msg.include?("style")

          :unknown_violation
        end
      end

      def rule_id
        return @requirement_id_override if @requirement_id_override
        return @rule.id if @rule.respond_to?(:id)

        if @rule.respond_to?(:class) && @rule.class.respond_to?(:name)
          # Extract ID from class name for requirements
          class_name = @rule.class.name.split("::").last
          class_name.gsub(/Requirement$/, "").downcase.gsub(/([a-z])([A-Z])/,
                                                            '\1_\2').downcase
        else
          "unknown"
        end
      end
    end
  end
end
