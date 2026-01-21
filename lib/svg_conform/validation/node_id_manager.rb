# frozen_string_literal: true

require_relative "../document_analyzer"

module SvgConform
  module Validation
    # Manages node ID generation for validation contexts
    # Wraps DocumentAnalyzer for DOM mode and handles ElementProxy for SAX mode
    class NodeIdManager
      def initialize(document = nil)
        @document = document
        @analyzer = nil # Lazy-loaded, only needed for DOM/remediation mode
      end

      # Generate a unique identifier for a node based on its path
      # Uses DocumentAnalyzer for efficient forward-counting algorithm (DOM mode)
      # For SAX mode, uses the pre-computed path from ElementProxy
      def generate_node_id(node)
        # In SAX mode, node may be an ElementProxy with pre-computed path
        return node.path_id if node.respond_to?(:path_id)

        # Lazy-load the analyzer only when needed (DOM/remediation mode)
        @analyzer ||= DocumentAnalyzer.new(@document) if @document
        return nil unless @analyzer

        @analyzer.get_node_id(node)
      end

      # Check if the manager has a document for DOM-based ID generation
      def dom_mode?
        !@document.nil?
      end
    end
  end
end
