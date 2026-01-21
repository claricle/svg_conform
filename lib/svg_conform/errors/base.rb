# frozen_string_literal: true

module SvgConform
  module Errors
    # Base class for all SvgConform error types
    #
    # Provides common interface for error and notice objects
    # used during validation.
    class Base
      attr_reader :type, :node, :message

      # Initialize a new error/notice
      #
      # @param type [Symbol] The type (:error, :warning, :info, etc.)
      # @param node [Object] The node associated with this error
      # @param message [String] The error message
      def initialize(type:, node:, message:)
        @type = type
        @node = node
        @message = message
      end

      # Get the line number of the error
      #
      # @return [Integer, nil] The line number if available
      def line
        @node.respond_to?(:line) ? @node.line : nil
      end

      # Get the column number of the error
      #
      # @return [Integer, nil] The column number if available
      def column
        @node.respond_to?(:column) ? @node.column : nil
      end

      # Get the element name of the error
      #
      # @return [String, nil] The element name if available
      def element_name
        @node.respond_to?(:name) ? @node.name : nil
      end

      # Convert error to hash representation
      #
      # @return [Hash] Hash representation of the error
      def to_h
        {
          type: @type,
          message: @message,
          line: line,
          column: column,
          element: element_name,
        }
      end
    end
  end
end
