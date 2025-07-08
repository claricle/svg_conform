# frozen_string_literal: true

require_relative 'validity_analysis'

module SvgConform
  module Compatibility
    # Model for discovered validation patterns
    class DiscoveredPattern < Lutaml::Model::Serializable
      attribute :source_tool, :string
      attribute :message_text, :string
      attribute :pattern_category, :string
      attribute :frequency, :integer
      attribute :files_affected, :string, collection: true
      attribute :suggested_semantic_key, :string
      attribute :confidence_level, :float

      def initialize(source_tool:, message_text:, pattern_category: 'unknown')
        @source_tool = source_tool
        @message_text = message_text
        @pattern_category = pattern_category
        @frequency = 1
        @files_affected = []
        @confidence_level = 0.0
      end

      def increment_frequency(filename)
        @frequency += 1
        @files_affected << filename unless @files_affected.include?(filename)
      end

      def suggest_semantic_key(key, confidence)
        @suggested_semantic_key = key
        @confidence_level = confidence
      end

      def high_confidence?
        @confidence_level >= 0.8
      end

      def common_pattern?
        @frequency >= 3
      end
    end

    # Enhanced pattern discovery engine
    class PatternDiscoveryEngine
      attr_reader :discovered_patterns, :unmapped_patterns

      def initialize
        @discovered_patterns = {}
        @unmapped_patterns = []
        @semantic_comparator = SvgConform::SemanticComparator.new
      end

      def discover_patterns_from_files(target_files)
        puts "🔍 Discovering validation patterns from #{target_files.length} files..."

        target_files.each do |filename|
          analyze_file_patterns(filename)
        end

        categorize_patterns
        suggest_semantic_mappings
        identify_unmapped_patterns

        generate_discovery_report
      end

      def analyze_file_patterns(filename)
        puts "  📄 Analyzing patterns in: #{filename}"

        # Analyze SvgConform patterns
        svg_conform_patterns = extract_svg_conform_patterns(filename)
        svg_conform_patterns.each do |pattern|
          record_pattern('svg_conform', pattern, filename)
        end

        # Analyze svgcheck patterns
        svgcheck_patterns = extract_svgcheck_patterns(filename)
        svgcheck_patterns.each do |pattern|
          record_pattern('svgcheck', pattern, filename)
        end
      end

      private

      def extract_svg_conform_patterns(filename)
        patterns = []

        begin
          # Run SvgConform validation to get patterns
          file_path = File.join('spec/fixtures/svgcheck/inputs', filename)
          return patterns unless File.exist?(file_path)

          validator = SvgConform::Validator.new(
            profile: 'svg_1_2_rfc'
          )

          result = validator.validate(file_path)

          if result.respond_to?(:issues)
            result.issues.each do |issue|
              patterns << normalize_pattern(issue.to_s)
            end
          end
        rescue StandardError => e
          puts "    ⚠️  Error extracting SvgConform patterns: #{e.message}"
        end

        patterns
      end

      def extract_svgcheck_patterns(filename)
        patterns = []

        begin
          # Read svgcheck repair output
          repair_file = File.join('spec/fixtures/svgcheck/repair',
                                  "#{filename}.out")
          return patterns unless File.exist?(repair_file)

          content = File.read(repair_file)

          # Extract validation messages using raw parser
          parser = SvgConform::SvgcheckRawParser.new
          parsed_result = parser.parse_content(content)

          if parsed_result.respond_to?(:messages)
            parsed_result.messages.each do |message|
              patterns << normalize_pattern(message.to_s)
            end
          end
        rescue StandardError => e
          puts "    ⚠️  Error extracting svgcheck patterns: #{e.message}"
        end

        patterns
      end

      def normalize_pattern(message)
        # Normalize patterns for better matching
        normalized = message.to_s.strip

        # Remove file-specific details
        normalized = normalized.gsub(/line \d+/i, 'line X')
        normalized = normalized.gsub(/column \d+/i, 'column X')
        normalized = normalized.gsub(/"[^"]*"/, '"VALUE"')
        normalized = normalized.gsub(/'[^']*'/, "'VALUE'")

        # Normalize common variations
        normalized = normalized.gsub(/\s+/, ' ')
        normalized.downcase
      end

      def record_pattern(source_tool, pattern_text, filename)
        key = "#{source_tool}:#{pattern_text}"

        if @discovered_patterns[key]
          @discovered_patterns[key].increment_frequency(filename)
        else
          pattern = DiscoveredPattern.new(
            source_tool: source_tool,
            message_text: pattern_text,
            pattern_category: categorize_pattern(pattern_text)
          )
          pattern.increment_frequency(filename)
          @discovered_patterns[key] = pattern
        end
      end

      def categorize_pattern(pattern_text)
        case pattern_text
        when /namespace/i
          'namespace_validation'
        when /viewbox/i
          'viewbox_validation'
        when /font/i
          'font_validation'
        when /color/i
          'color_validation'
        when /attribute/i
          'attribute_validation'
        when /element/i
          'element_validation'
        when /style/i
          'style_validation'
        else
          'unknown_validation'
        end
      end

      def categorize_patterns
        @discovered_patterns.each_value do |pattern|
          pattern.pattern_category = categorize_pattern(pattern.message_text) if pattern.pattern_category == 'unknown_validation'
        end
      end

      def suggest_semantic_mappings
        @discovered_patterns.each_value do |pattern|
          semantic_key = find_semantic_mapping(pattern)
          if semantic_key
            confidence = calculate_semantic_confidence(pattern, semantic_key)
            pattern.suggest_semantic_key(semantic_key, confidence)
          end
        end
      end

      def find_semantic_mapping(pattern)
        # Use existing semantic comparator to find mappings
        existing_mappings = @semantic_comparator.instance_variable_get(:@semantic_mappings)

        # Try to find existing mapping
        existing_mappings.each do |key, variations|
          variations.each do |variation|
            return key if pattern_matches_variation?(pattern.message_text, variation)
          end
        end

        # Generate new semantic key suggestion
        generate_semantic_key_suggestion(pattern)
      end

      def pattern_matches_variation?(pattern_text, variation)
        # Simple similarity check
        normalized_pattern = normalize_pattern(pattern_text)
        normalized_variation = normalize_pattern(variation)

        # Check for substring match or similar keywords
        normalized_pattern.include?(normalized_variation) ||
          normalized_variation.include?(normalized_pattern) ||
          share_keywords?(normalized_pattern, normalized_variation)
      end

      def share_keywords?(text1, text2)
        keywords1 = extract_keywords(text1)
        keywords2 = extract_keywords(text2)

        common_keywords = keywords1 & keywords2
        common_keywords.length >= 2
      end

      def extract_keywords(text)
        # Extract meaningful keywords
        words = text.split(/\s+/)
        words.select do |word|
          word.length > 3 &&
            !%w[the and or but with from that this].include?(word)
        end
      end

      def generate_semantic_key_suggestion(pattern)
        # Generate semantic key based on pattern category and content
        category = pattern.pattern_category.gsub('_validation', '')

        keywords = extract_keywords(pattern.message_text)
        key_suffix = keywords.first(2).join('_')

        "#{category}_#{key_suffix}".downcase
      end

      def calculate_semantic_confidence(pattern, semantic_key)
        confidence = 0.5 # Base confidence

        # Increase confidence for common patterns
        confidence += 0.2 if pattern.common_pattern?

        # Increase confidence for well-categorized patterns
        confidence += 0.2 if pattern.pattern_category != 'unknown_validation'

        # Increase confidence for existing mappings
        confidence += 0.3 if semantic_key_exists?(semantic_key)

        [confidence, 1.0].min
      end

      def semantic_key_exists?(semantic_key)
        existing_mappings = @semantic_comparator.instance_variable_get(:@semantic_mappings)
        existing_mappings.key?(semantic_key)
      end

      def identify_unmapped_patterns
        @unmapped_patterns = @discovered_patterns.values.select do |pattern|
          pattern.suggested_semantic_key.nil? ||
            pattern.confidence_level < 0.6
        end
      end

      def generate_discovery_report
        puts
        puts '=== Pattern Discovery Report ==='
        puts "Total patterns discovered: #{@discovered_patterns.length}"
        puts "Unmapped patterns: #{@unmapped_patterns.length}"
        puts

        puts '🔍 High-confidence new mappings:'
        high_confidence_new = @discovered_patterns.values.select do |pattern|
          pattern.high_confidence? &&
            !semantic_key_exists?(pattern.suggested_semantic_key)
        end

        high_confidence_new.each do |pattern|
          puts "  #{pattern.suggested_semantic_key}: #{pattern.message_text}"
          puts "    Confidence: #{(pattern.confidence_level * 100).round(1)}%"
          puts "    Frequency: #{pattern.frequency} files"
          puts
        end

        puts '❓ Unmapped patterns requiring investigation:'
        @unmapped_patterns.each do |pattern|
          puts "  [#{pattern.source_tool}] #{pattern.message_text}"
          puts "    Category: #{pattern.pattern_category}"
          puts "    Frequency: #{pattern.frequency} files"
          puts
        end
      end
    end
  end
end
