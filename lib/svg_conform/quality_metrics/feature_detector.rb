# frozen_string_literal: true

module SvgConform
  module QualityMetrics
    # Detects SVG features in file content using regex patterns.
    #
    # @example
    #   config = Configuration.default
    #   detector = FeatureDetector.new(config)
    #
    #   features = detector.detect(File.read('image.svg'))
    #   puts features.has_base64?  # => false
    #   puts features.present_features  # => [:masks, :clip_paths]
    #
    class FeatureDetector
      # @param config [Configuration]
      def initialize(config)
        @config = config
      end

      # Detect features in content or file
      #
      # @param content_or_path [String] Either raw SVG content or path to file
      # @return [FeatureFlags]
      def detect(content_or_path)
        content = read_content(content_or_path)

        FeatureFlags.new(
          has_base64: match_pattern?(:base64, content),
          has_foreign_ns: match_pattern?(:foreign_ns, content),
          has_masks: match_pattern?(:masks, content),
          has_clip_paths: match_pattern?(:clip_paths, content),
          has_external_refs: match_pattern?(:external_refs, content),
        )
      end

      private

      def read_content(content_or_path)
        if File.exist?(content_or_path)
          File.read(content_or_path)
        else
          content_or_path.to_s
        end
      end

      def match_pattern?(name, content)
        pattern = @config.feature_patterns[name]
        return false unless pattern

        !content.match(pattern).nil?
      end
    end
  end
end
