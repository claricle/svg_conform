# frozen_string_literal: true

require_relative "base"

module SvgConform
  module Errors
    # Validation notice (informational message, not an error)
    #
    # Represents informational notices during validation, such as
    # external reference notices or other non-error messages.
    class ValidationNotice < Base
      attr_reader :data

      def initialize(type:, node:, message:, data: {})
        super(type: type, node: node, message: message)
        @data = data
      end

      def to_h
        {
          type: @type,
          message: @message,
          line: line,
          column: column,
          data: @data,
        }
      end
    end
  end
end
