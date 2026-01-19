# frozen_string_literal: true

module SvgConform
  # Represents a non-error notification during validation.
  #
  # Used for informational messages such as external references
  # that are not errors but should be noted.
  class ValidationNotice
    attr_reader :type, :node, :message, :data

    # Initialize a new validation notice
    #
    # @param type [Symbol] the notice type (e.g., :external_reference)
    # @param node [Object] the node where the notice applies
    # @param message [String] the notice message
    # @param data [Hash] additional data about the notice
    def initialize(type:, node:, message:, data: {})
      @type = type
      @node = node
      @message = message
      @data = data
    end

    # Get the line number where this notice applies
    # @return [Integer, nil] the line number
    def line
      @node.respond_to?(:line) ? @node.line : nil
    end

    # Get the column number where this notice applies
    # @return [Integer, nil] the column number
    def column
      @node.respond_to?(:column) ? @node.column : nil
    end

    # Convert to hash representation
    # @return [Hash] hash representation
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
