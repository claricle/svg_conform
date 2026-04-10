# frozen_string_literal: true

require "lutaml/model"

module SvgConform
  module QualityMetrics
    # Immutable value object representing detected SVG features.
    #
    # @example
    #   features = FeatureFlags.new(
    #     has_base64: true,
    #     has_masks: true,
    #     has_external_refs: false
    #   )
    #
    #   features.has_base64?        # => true
    #   features.advanced_features   # => [:base64, :masks]
    #
    class FeatureFlags < Lutaml::Model::Serializable
      attribute :has_base64, :boolean, default: false
      attribute :has_foreign_ns, :boolean, default: false
      attribute :has_masks, :boolean, default: false
      attribute :has_clip_paths, :boolean, default: false
      attribute :has_external_refs, :boolean, default: false

      after_initialize { freeze }

      # Value equality
      def ==(other)
        other.is_a?(FeatureFlags) &&
          has_base64 == other.has_base64 &&
          has_foreign_ns == other.has_foreign_ns &&
          has_masks == other.has_masks &&
          has_clip_paths == other.has_clip_paths &&
          has_external_refs == other.has_external_refs
      end
      alias eql? ==

      def hash
        [has_base64, has_foreign_ns, has_masks, has_clip_paths, has_external_refs].hash
      end

      # @return [Boolean] true if any advanced features are present
      def has_advanced_features?
        advanced_feature_count.positive?
      end

      # @return [Array<Symbol>] List of present feature names
      def present_features
        features = []
        features << :base64 if has_base64
        features << :foreign_ns if has_foreign_ns
        features << :masks if has_masks
        features << :clip_paths if has_clip_paths
        features << :external_refs if has_external_refs
        features
      end

      # @return [Integer] Count of advanced features present
      def advanced_feature_count
        present_features.size
      end
    end
  end
end
