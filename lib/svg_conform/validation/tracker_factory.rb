# frozen_string_literal: true

require_relative "../references"
require_relative "error_tracker"
require_relative "structural_invalidity_tracker"
require_relative "node_id_manager"

module SvgConform
  module Validation
    # Factory for creating tracker objects used in ValidationContext
    # Centralizes tracker object creation for cleaner initialization
    module TrackerFactory
      # Create a new ErrorTracker instance
      def self.create_error_tracker
        ErrorTracker.new
      end

      # Create a new NodeIdManager instance
      # @param document [Document, nil] The document (nil for SAX mode)
      def self.create_node_id_manager(document)
        NodeIdManager.new(document)
      end

      # Create a new StructuralInvalidityTracker instance
      # @param node_id_generator [Proc] Callable that generates node IDs
      def self.create_structural_invalidity_tracker(node_id_generator:)
        StructuralInvalidityTracker.new(node_id_generator: node_id_generator)
      end

      # Create a new ReferenceManifest instance
      # @param source_document [String, nil] Optional source document path
      def self.create_reference_manifest(source_document: nil)
        References::ReferenceManifest.new(source_document: source_document)
      end

      # Create all trackers for a ValidationContext
      # @param document [Document, nil] The document (nil for SAX mode)
      # @return [Hash] Hash of tracker instances
      def self.create_all_trackers(document)
        node_id_manager = create_node_id_manager(document)

        {
          error_tracker: create_error_tracker,
          node_id_manager: node_id_manager,
          structural_invalidity_tracker: create_structural_invalidity_tracker(
            node_id_generator: ->(node) {
              node_id_manager.generate_node_id(node)
            },
          ),
          reference_manifest: create_reference_manifest(source_document: document&.file_path),
        }
      end
    end
  end
end
