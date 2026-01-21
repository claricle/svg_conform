# frozen_string_literal: true

require_relative "errors/validation_issue"
require_relative "errors/validation_notice"

# Backward compatibility: re-export error classes at top level
module SvgConform
  # Aliases for backward compatibility
  # These classes are now defined in SvgConform::Errors
  ValidationIssue = Errors::ValidationIssue
  ValidationNotice = Errors::ValidationNotice
end
