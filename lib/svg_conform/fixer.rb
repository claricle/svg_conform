# frozen_string_literal: true

module SvgConform
  # Utility class for applying fixes to SVG documents
  class Fixer
    attr_reader :document, :fixes_applied

    def initialize(document)
      @document = document
      @fixes_applied = []
    end

    # Apply a single fix
    def apply_fix(fix)
      return false unless fix.respond_to?(:call) || fix.respond_to?(:apply)

      begin
        result = if fix.respond_to?(:call)
                   fix.call
                 else
                   fix.apply
                 end

        @fixes_applied << fix if result
        result
      rescue StandardError
        false
      end
    end

    # Apply multiple fixes
    def apply_fixes(fixes)
      success_count = 0

      fixes.each do |fix|
        success_count += 1 if apply_fix(fix)
      end

      success_count
    end

    # Apply all fixable issues from a validation result
    def apply_validation_fixes(validation_result)
      fixable_issues = (validation_result.errors + validation_result.warnings).select(&:fixable?)
      apply_fixes(fixable_issues.map(&:fix))
    end

    def fixes_count
      @fixes_applied.size
    end

    def to_xml
      @document.to_xml
    end
  end
end
