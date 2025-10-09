# frozen_string_literal: true

require_relative "remediations/base_remediation"
require_relative "remediations/color_remediation"
require_relative "remediations/font_remediation"
require_relative "remediations/invalid_id_references_remediation"
require_relative "remediations/namespace_attribute_remediation"
require_relative "remediations/namespace_remediation"
require_relative "remediations/no_external_css_remediation"
require_relative "remediations/style_promotion_remediation"
require_relative "remediations/viewbox_remediation"

module SvgConform
  module Remediations
    # Auto-load all remediation classes
    def self.all
      [
        ColorRemediation,
        FontRemediation,
        InvalidIdReferencesRemediation,
        NamespaceAttributeRemediation,
        NamespaceRemediation,
        NoExternalCSSRemediation,
        StylePromotionRemediation,
        ViewboxRemediation,
      ]
    end

    # Find a remediation class by name
    def self.find(class_name)
      const_get(class_name)
    rescue NameError
      nil
    end
  end
end
