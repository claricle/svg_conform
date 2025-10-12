# frozen_string_literal: true

# This file provides backward compatibility for users of the xml-c14n gem.
# It redirects to the new canon gem.

require_relative "canon"

# For backward compatibility
module Xml
  C14n = Canon
end
