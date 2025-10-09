# frozen_string_literal: true

require_relative "requirements/base_requirement"
require_relative "requirements/allowed_elements_requirement"
require_relative "requirements/color_restrictions_requirement"
require_relative "requirements/font_family_requirement"
require_relative "requirements/invalid_id_references_requirement"
require_relative "requirements/namespace_requirement"
require_relative "requirements/no_external_css_requirement"
require_relative "requirements/viewbox_required_requirement"
require_relative "requirements/namespace_attributes_requirement"
require_relative "requirements/forbidden_content_requirement"
require_relative "requirements/style_requirement"
require_relative "requirements/style_promotion_requirement"
require_relative "requirements/link_validation_requirement"
require_relative "requirements/id_reference_requirement"

module SvgConform
  module Requirements
    # Auto-load all requirement classes
    def self.all
      [
        AllowedElementsRequirement,
        ColorRestrictionsRequirement,
        FontFamilyRequirement,
        InvalidIdReferencesRequirement,
        NamespaceRequirement,
        NoExternalCssRequirement,
        ViewboxRequiredRequirement,
        NamespaceAttributesRequirement,
        ForbiddenContentRequirement,
        StyleRequirement,
        LinkValidationRequirement,
        IdReferenceRequirement,
      ]
    end

    # Find a requirement class by name
    def self.find(class_name)
      const_get(class_name)
    rescue NameError
      nil
    end
  end
end
