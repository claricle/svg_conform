# frozen_string_literal: true

require_relative "svgcheck_patterns"
require_relative "normalizer"

module SvgConform
  module Comparison
    # Semantic key extraction for error messages
    #
    # This module provides pattern-matching logic to extract semantic keys
    # from error messages. It uses the centralized pattern registry and
    # normalization utilities to ensure consistent semantic comparison.
    #
    # PERFORMANCE: Includes memoization cache for repeated issue processing.
    # SECURITY: Message length is limited to prevent ReDoS attacks.
    # All patterns use quantifier limits to prevent exponential backtracking.
    module SemanticExtractor
      class << self
        include SvgcheckPatterns
        include Normalizer

        # Memoization cache for repeated issue processing
        # Key: issue.object_id, Value: semantic_key
        # Cleared after each batch validation to prevent memory bloat
        def memoization_cache
          @memoization_cache ||= {}
        end

        # Clear memoization cache (call after batch validations)
        def clear_memoization_cache
          @memoization_cache&.clear
          @memoization_cache = nil
        end

        # Extract semantic key from an issue (with memoization)
        #
        # Maps error messages to semantic keys for comparison. This enables
        # semantic matching rather than exact string matching.
        #
        # PERFORMANCE: Memoizes results by issue.object_id to avoid repeated
        # regex matching on the same issue objects during batch processing.
        #
        # @param issue [Object] the issue object (may have message method or be Hash/String)
        # @return [String] the semantic key for this issue
        def extract_semantic_key(issue)
          # Check memoization cache first
          issue_id = issue.object_id
          cached_key = memoization_cache[issue_id]
          return cached_key if cached_key

          # Handle different issue types
          message = if issue.respond_to?(:message)
                      issue.message
                    elsif issue.is_a?(Hash)
                      issue[:message] || issue["message"]
                    else
                      issue.to_s
                    end

          # SECURITY: Prevent ReDoS attacks by limiting message length
          # GitHub CodeQL: Regular expressions with excessive backtracking can cause DoS
          # This affects svgcheck comparison commands (development use only)
          # Note: Ruby 3.2+ has built-in regex caching that prevents ReDoS
          if message.length > 1000
            # Truncate very long messages to prevent exponential backtracking
            message = "#{message[0, 997]}..."
          end

          # Map ONLY the exact 28 svgcheck.py log patterns to semantic keys
          # SECURITY: Regex patterns use quantifier limits to prevent ReDoS
          semantic_key = case message
                         # Error patterns from checksvg.py (4 patterns)
                         when SvgcheckPatterns::MALFORMED_STYLE_FIELD
                           "malformed_style_field:#{normalize_value(::Regexp.last_match(1))}"
                         when SvgcheckPatterns::MALFORMED_STYLE_FIELD_ARRAY
                           "malformed_style_field:#{normalize_value(::Regexp.last_match(1))}"
                         when SvgcheckPatterns::MALFORMED_STYLE_DECLARATION
                           "malformed_style_field:#{normalize_value(::Regexp.last_match(1))}"
                         when SvgcheckPatterns::STYLE_PROMOTED
                           "style_promotion:#{::Regexp.last_match(1)}"
                         when SvgcheckPatterns::STYLE_PROPERTY_REMOVED
                           "style_property_removed:#{::Regexp.last_match(1)}"
                         when SvgcheckPatterns::SVG_SIZE_ERROR
                           "informative:svg_size_calculation_error"
                         when SvgcheckPatterns::FILE_NONCONFORMANT
                           "informative:file_nonconformant"

                         # Warning patterns from checksvg.py (10 patterns)
                         when SvgcheckPatterns::INVALID_ELEMENT_NAMESPACE
                           "invalid_element_namespace:#{::Regexp.last_match(1)}:#{normalize_namespace(::Regexp.last_match(2))}"
                         when SvgcheckPatterns::INVALID_ELEMENT
                           "invalid_element:#{::Regexp.last_match(1)}"
                         when SvgcheckPatterns::NAMESPACE_VIOLATION_ELEMENT
                           "namespace_violation:#{::Regexp.last_match(1)}:#{normalize_namespace(::Regexp.last_match(2))}"
                         when SvgcheckPatterns::INVALID_ATTRIBUTE
                           "invalid_attribute:#{::Regexp.last_match(1)}:#{::Regexp.last_match(2)}"
                         when SvgcheckPatterns::INVALID_ATTRIBUTE_VALUE_REPLACED
                           # Normalize color values for semantic equivalence
                           attribute = ::Regexp.last_match(1)
                           value = ::Regexp.last_match(2)

                           # For color attributes, use normalized color values
                           if color_attribute?(attribute)
                             "invalid_attribute_value:#{attribute}:#{normalize_color_value(value)}"
                           else
                             "invalid_attribute_value:#{attribute}:#{normalize_value(value)}"
                           end
                         when SvgcheckPatterns::INVALID_ATTRIBUTE_VALUE_REMOVED
                           "invalid_attribute_value:#{::Regexp.last_match(1)}:#{normalize_value(::Regexp.last_match(2))}"
                         when SvgcheckPatterns::VIEWBOX_REQUIRED
                           "viewbox_required"
                         when SvgcheckPatterns::VIEWBOX_AUTO_ADDED
                           "informative:viewbox_auto_added"
                         when SvgcheckPatterns::NAMESPACE_NOT_PERMITTED
                           "namespace_violation:element:#{normalize_namespace(::Regexp.last_match(1))}"
                         when SvgcheckPatterns::INVALID_CHILD
                           "invalid_child:#{::Regexp.last_match(1)}:#{::Regexp.last_match(2)}"
                         when SvgcheckPatterns::MALFORMED_NAMESPACE
                           "informative:malformed_namespace"
                         when SvgcheckPatterns::DEPRECATED_OPTION
                           "informative:deprecated_option"

                         # Note patterns from checksvg.py (13 patterns)
                         when SvgcheckPatterns::MODIFY_STYLE_CHECK
                           "informative:modify_style_check"
                         when SvgcheckPatterns::MODIFY_STYLE_PROCESSING
                           "informative:modify_style_processing"
                         when SvgcheckPatterns::VALUE_OK_LOOK
                           "informative:value_validation"
                         when SvgcheckPatterns::LEGAL_VALUE_LIST
                           "informative:legal_values"
                         when SvgcheckPatterns::SKIP_TO_END
                           "informative:validation_skip"
                         when SvgcheckPatterns::COLOR_HEURISTIC
                           "informative:color_heuristic"
                         when SvgcheckPatterns::TAG_PROCESSING
                           "informative:element_processing"
                         when SvgcheckPatterns::ELEMENT_PROCESSING
                           "informative:element_attributes"
                         when SvgcheckPatterns::ATTRIBUTE_PROCESSING
                           "informative:attribute_processing"
                         when SvgcheckPatterns::CHILD_PROCESSING
                           "informative:child_processing"
                         when SvgcheckPatterns::SVG_ELEMENT_CHECK
                           "informative:svg_element_check"

                         # SvgConform-specific patterns that map to svgcheck semantic equivalents
                         when SvgcheckPatterns::COLOR_NOT_ALLOWED_ATTRIBUTE
                           # Map SvgConform color restriction to svgcheck invalid_attribute_value pattern
                           # Normalize color values to handle different formats (WHITE -> white, etc.)
                           "invalid_attribute_value:#{::Regexp.last_match(2)}:#{normalize_color_value(::Regexp.last_match(1))}"
                         when SvgcheckPatterns::COLOR_NOT_ALLOWED_STYLE
                           # Map SvgConform style property color restriction to svgcheck invalid_attribute_value pattern
                           # Svgcheck promotes style properties to attributes, so we map accordingly
                           "invalid_attribute_value:#{::Regexp.last_match(2)}:#{normalize_color_value(::Regexp.last_match(1))}"
                         when SvgcheckPatterns::FONT_FAMILY_NOT_ALLOWED
                           # Map SvgConform font family restriction to svgcheck invalid_attribute_value pattern
                           "invalid_attribute_value:font-family:#{normalize_value(::Regexp.last_match(1))}"
                         when SvgcheckPatterns::FONT_FAMILY_IN_STYLE_NOT_ALLOWED
                           # Map SvgConform style font family restriction to svgcheck invalid_attribute_value pattern
                           font_family = normalize_value(::Regexp.last_match(1))
                           # Embedded font restrictions are profile differences
                           if font_family.include?("embedded")
                             "informative:profile_stricter_embedded_fonts:#{font_family}"
                           else
                             "invalid_attribute_value:font-family:#{font_family}"
                           end
                         when SvgcheckPatterns::SVG_ROOT_VIEWBOX_REQUIRED
                           # Map SvgConform viewBox requirement to svgcheck pattern (case insensitive)
                           "viewbox_required"
                         when SvgcheckPatterns::ELEMENT_NOT_ALLOWED_PROFILE
                           # Map SvgConform element restriction to svgcheck invalid_child pattern
                           element = ::Regexp.last_match(1)
                           # Font-related and clipPath elements are profile differences, not validation errors
                           if %w[font glyph font-face missing-glyph
                                 clipPath].include?(element)
                             "informative:profile_stricter_elements:#{element}"
                           else
                             "invalid_child:#{element}:svg"
                           end
                         when SvgcheckPatterns::CHILD_NOT_ALLOWED_PROFILE
                           # Map SvgConform child element restriction to svgcheck pattern
                           element = ::Regexp.last_match(1)
                           parent = ::Regexp.last_match(2)
                           # Font-related and clipPath elements as children are profile differences
                           if %w[font glyph font-face missing-glyph
                                 clipPath].include?(element)
                             "informative:profile_stricter_elements:#{element}:#{parent}"
                           else
                             "invalid_child:#{element}:#{parent}"
                           end
                         when SvgcheckPatterns::ATTRIBUTE_NOT_ALLOWED
                           # Map SvgConform attribute restriction to svgcheck pattern
                           "invalid_attribute:#{::Regexp.last_match(2)}:#{::Regexp.last_match(1)}"
                         when SvgcheckPatterns::NAMESPACE_NOT_PERMITTED_SVGCONFORM
                           # Map SvgConform namespace restriction to svgcheck pattern
                           "namespace_violation:element:#{normalize_namespace(::Regexp.last_match(1))}"
                         when SvgcheckPatterns::VIEWBOX_FORMAT_ERROR
                           # Map SvgConform viewBox format validation (more strict than svgcheck)
                           "viewbox_format_error"

                         # Everything else maps to "other" for non-svgcheck messages
                         else
                           "other:#{normalize_message(message)}"
                         end

          # Memoize the result for this issue
          memoization_cache[issue_id] = semantic_key
          semantic_key
        end

        # Group issues by semantic meaning
        #
        # Takes a collection of issues and groups them by their semantic key.
        #
        # PERFORMANCE: Uses memoized extract_semantic_key for efficient processing.
        #
        # @param issues [Array] the issues to group
        # @return [Hash] hash mapping semantic keys to issue counts
        def group_issues_semantically(issues)
          semantic_groups = {}

          issues.each do |issue|
            semantic_key = extract_semantic_key(issue)
            semantic_groups[semantic_key] ||= []
            semantic_groups[semantic_key] << issue
          end

          semantic_groups.transform_values(&:length)
        end
      end
    end
  end
end
