# frozen_string_literal: true

module SvgConform
  module Comparison
    # Centralized registry of SVGCheck regex patterns for semantic comparison
    #
    # This module provides a single source of truth for all SVGCheck message patterns
    # used in semantic comparison. Patterns are lazy-compiled and include quantifier limits
    # to prevent ReDoS attacks.
    #
    # SECURITY: All patterns use quantifier limits to prevent exponential backtracking.
    # See semantic_comparator.rb for additional ReDoS protection measures.
    module SvgcheckPatterns
      # Error patterns from checksvg.py (4 patterns)
      MALFORMED_STYLE_FIELD_ARRAY = /\AMalformed field '(\[[^\]]{1,200}\])' in style attribute found\. Field removed\.\z/
      MALFORMED_STYLE_FIELD = /\AMalformed field '([^']{1,200})' in style attribute found\. Field removed\.\z/
      MALFORMED_STYLE_DECLARATION = /\AMalformed style declaration '([^']{1,200})' found\. Declaration removed\.\z/
      STYLE_PROMOTED = /\AStyle property '([^']{1,100})' promoted to attribute\z/
      STYLE_PROPERTY_REMOVED = /\AStyle property '([^']{1,100})' removed\z/
      SVG_SIZE_ERROR = /\AError when calculating SVG size: (.{1,500})\z/
      FILE_NONCONFORMANT = /\AFile does not conform to SVG requirements\z/

      # Warning patterns from checksvg.py (10 patterns)
      INVALID_ELEMENT_NAMESPACE = /\AElement '([^']{1,100})' in namespace '([^']{1,200})' is not allowed\z/
      INVALID_ELEMENT = /\AElement '([^']{1,100})' not allowed\z/
      NAMESPACE_VIOLATION_ELEMENT = /\AElement '([^']{1,100})' does not allow attributes with namespace '([^']{1,200})'\z/
      INVALID_ATTRIBUTE = /\AThe element '([^']{1,100})' does not allow the attribute '([^']{1,100})', attribute to be removed\.\z/
      INVALID_ATTRIBUTE_VALUE_REPLACED = /\AThe attribute '([^']{1,100})' does not allow the value '([^']{1,200})', replaced with '([^']{1,200})'\z/
      INVALID_ATTRIBUTE_VALUE_REMOVED = /\AThe attribute '([^']{1,100})' does not allow the value '([^']{1,200})', attribute to be removed\z/
      VIEWBOX_REQUIRED = /\AThe attribute viewBox is required on the root svg element\z/
      VIEWBOX_AUTO_ADDED = /\ATrying to put in the attribute with value '([^']{1,200})'\z/
      NAMESPACE_NOT_PERMITTED = /\AThe namespace ([^\s]{1,200}) is not permitted for svg elements\.\z/
      INVALID_CHILD = /\AThe element '([^']{1,100})' is not allowed as a child of '([^']{1,100})'\z/
      MALFORMED_NAMESPACE = /\AMalformed namespace\. Should have errored during parsing\z/
      DEPRECATED_OPTION = /\A--no-xinclude option is deprecated and has no effect\.\z/

      # Note patterns from checksvg.py (13 patterns)
      MODIFY_STYLE_CHECK = /\Amodify_style check '([^']{1,100})' in '([^']{1,100})'\z/
      MODIFY_STYLE_PROCESSING = /\A   modify_style - p=([^\s]{1,100})  v=(.{1,200})\z/
      VALUE_OK_LOOK = /\Avalue_ok look for (.{1,200}) in (.{1,200})\z/
      LEGAL_VALUE_LIST = /\A  legal value list (.{1,500})\z/
      SKIP_TO_END = /\A --- skip to end -- (.{1,200})\z/
      COLOR_HEURISTIC = /\AColor or grayscale heuristic applied to: '([^']{1,100})' yields shade: '([^']{1,100})'\z/
      TAG_PROCESSING = /\A[^\s]{1,50} tag = (.{1,200})\z/
      ELEMENT_PROCESSING = /\A[^\s]{1,50} element [^:]{1,50}: (.{1,200})\z/
      ATTRIBUTE_PROCESSING = /\A[^\s]{1,50} attr ([^\s]{1,100}) = ([^\s]{1,200}) \(ns = ([^)]{0,200})\)\z/
      CHILD_PROCESSING = /\A[^\s]{1,50}child, tag = (.{1,200})\z/
      SVG_ELEMENT_CHECK = /\AChecking svg element at line (\d{1,10}) in file (.{1,500})\z/

      # SvgConform-specific patterns that map to svgcheck semantic equivalents
      COLOR_NOT_ALLOWED_ATTRIBUTE = /\AColor '([^']{1,100})' in attribute '([^']{1,100})' is not allowed in this profile\z/
      COLOR_NOT_ALLOWED_STYLE = /\AColor '([^']{1,100})' in style property '([^']{1,100})' is not allowed in this profile\z/
      FONT_FAMILY_NOT_ALLOWED = /\AFont family '([^']{1,200})' is not allowed in this profile\z/
      FONT_FAMILY_IN_STYLE_NOT_ALLOWED = /\AFont family '([^']{1,200})' in style is not allowed in this profile\z/
      SVG_ROOT_VIEWBOX_REQUIRED = /\Asvg root element must have a viewbox attribute\z/i
      ELEMENT_NOT_ALLOWED_PROFILE = /\AElement '([^']{1,100})' is not allowed in this profile\z/
      CHILD_NOT_ALLOWED_PROFILE = /\AThe element '([^']{1,100})' is not allowed as a child of '([^']{1,100})'\z/
      ATTRIBUTE_NOT_ALLOWED = /\AAttribute '([^']{1,100})' is not allowed on element '([^']{1,100})'\z/
      NAMESPACE_NOT_PERMITTED_SVGCONFORM = /\AThe namespace ([^\s]{1,200}) is not permitted for svg elements\.?\z/
      VIEWBOX_FORMAT_ERROR = /\AviewBox attribute must contain four numeric values/i

      # Helper method to get all patterns as a hash for easy iteration
      def self.all_patterns
        {
          malformed_style_field_array: MALFORMED_STYLE_FIELD_ARRAY,
          malformed_style_field: MALFORMED_STYLE_FIELD,
          malformed_style_declaration: MALFORMED_STYLE_DECLARATION,
          style_promoted: STYLE_PROMOTED,
          style_property_removed: STYLE_PROPERTY_REMOVED,
          svg_size_error: SVG_SIZE_ERROR,
          file_nonconformant: FILE_NONCONFORMANT,
          invalid_element_namespace: INVALID_ELEMENT_NAMESPACE,
          invalid_element: INVALID_ELEMENT,
          namespace_violation_element: NAMESPACE_VIOLATION_ELEMENT,
          invalid_attribute: INVALID_ATTRIBUTE,
          invalid_attribute_value_replaced: INVALID_ATTRIBUTE_VALUE_REPLACED,
          invalid_attribute_value_removed: INVALID_ATTRIBUTE_VALUE_REMOVED,
          vbox_required: VIEWBOX_REQUIRED,
          vbox_auto_added: VIEWBOX_AUTO_ADDED,
          namespace_not_permitted: NAMESPACE_NOT_PERMITTED,
          invalid_child: INVALID_CHILD,
          malformed_namespace: MALFORMED_NAMESPACE,
          deprecated_option: DEPRECATED_OPTION,
          modify_style_check: MODIFY_STYLE_CHECK,
          modify_style_processing: MODIFY_STYLE_PROCESSING,
          value_ok_look: VALUE_OK_LOOK,
          legal_value_list: LEGAL_VALUE_LIST,
          skip_to_end: SKIP_TO_END,
          color_heuristic: COLOR_HEURISTIC,
          tag_processing: TAG_PROCESSING,
          element_processing: ELEMENT_PROCESSING,
          attribute_processing: ATTRIBUTE_PROCESSING,
          child_processing: CHILD_PROCESSING,
          svg_element_check: SVG_ELEMENT_CHECK,
          color_not_allowed_attribute: COLOR_NOT_ALLOWED_ATTRIBUTE,
          color_not_allowed_style: COLOR_NOT_ALLOWED_STYLE,
          font_family_not_allowed: FONT_FAMILY_NOT_ALLOWED,
          font_family_in_style_not_allowed: FONT_FAMILY_IN_STYLE_NOT_ALLOWED,
          svg_root_vbox_required: SVG_ROOT_VIEWBOX_REQUIRED,
          element_not_allowed_profile: ELEMENT_NOT_ALLOWED_PROFILE,
          child_not_allowed_profile: CHILD_NOT_ALLOWED_PROFILE,
          attribute_not_allowed: ATTRIBUTE_NOT_ALLOWED,
          namespace_not_permitted_svgconform: NAMESPACE_NOT_PERMITTED_SVGCONFORM,
          vbox_format_error: VIEWBOX_FORMAT_ERROR,
        }
      end
    end
  end
end
