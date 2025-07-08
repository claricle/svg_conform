# frozen_string_literal: true

require 'yaml'

module SvgConform
  module ExternalCheckers
    module Svgcheck
      # Enhanced svgcheck output parser that uses mapping configuration
      class Parser
        attr_reader :mapping_config

        def initialize(mapping_config_path = nil)
          @mapping_config_path = mapping_config_path || 'config/svgcheck_mapping.yml'
          load_mapping_config
        end

        # Parse svgcheck output into a ConformanceReport
        def parse(output_content, error_content = nil, filename: nil)
          return create_empty_report(filename) if output_content.nil? || output_content.strip.empty?

          errors = parse_error_lines(output_content)
          create_report_from_errors(errors, filename)
        end

        private

        def load_mapping_config
          if File.exist?(@mapping_config_path)
            @mapping_config = YAML.load_file(@mapping_config_path)
          else
            # Fallback to empty config if file doesn't exist
            @mapping_config = {
              'message_patterns' => [],
              'requirement_mappings' => {},
              'skip_patterns' => [],
              'special_rules' => {}
            }
          end
        end

        def parse_error_lines(content)
          errors = []

          content.each_line do |line|
            line = line.strip
            next if line.empty?
            next if should_skip_line?(line)

            # Try to match against message patterns
            matched_error = match_against_patterns(line)
            if matched_error
              errors << matched_error
            else
              # Fallback to basic error structure for unmapped errors
              errors << create_unmapped_error(line)
            end
          end

          errors
        end

        def should_skip_line?(line)
          return false unless @mapping_config['skip_patterns']

          @mapping_config['skip_patterns'].each do |skip_pattern|
            pattern = skip_pattern['pattern']
            flags = skip_pattern['flags']

            regex_flags = 0
            regex_flags |= Regexp::IGNORECASE if flags&.include?('i')

            if line.match?(Regexp.new(pattern, regex_flags))
              return true
            end
          end

          false
        end

        def match_against_patterns(line)
          return nil unless @mapping_config['message_patterns']

          @mapping_config['message_patterns'].each do |pattern_config|
            pattern = pattern_config['pattern']
            requirement = pattern_config['requirement']
            semantic_key = pattern_config['semantic_key']

            match = line.match(Regexp.new(pattern))
            next unless match

            # Skip patterns that map to null requirement (unmapped errors)
            return nil if requirement.nil?

            return create_mapped_error(line, requirement, semantic_key, match)
          end

          nil
        end

        def create_mapped_error(line, requirement_id, semantic_key, match)
          # Substitute regex groups in semantic key
          processed_semantic_key = semantic_key
          if semantic_key && match.captures.any?
            match.captures.each_with_index do |capture, index|
              processed_semantic_key = processed_semantic_key.gsub("${#{index + 1}}", capture || '')
            end
          end

          issue = SvgConform::ConformanceIssue.new
          issue.type = 'error'
          issue.requirement_id = requirement_id
          issue.message = line

          # Extract semantic information from the match
          if match.captures.length >= 1
            issue.attribute = match.captures[0] if match.captures[0]
          end
          if match.captures.length >= 2
            issue.value = match.captures[1] if match.captures[1]
          end
          if match.captures.length >= 3
            issue.element = match.captures[2] if match.captures[2]
          end

          issue
        end

        def create_unmapped_error(line)
          issue = SvgConform::ConformanceIssue.new
          issue.type = 'error'
          issue.requirement_id = 'unmapped_svgcheck_error'
          issue.message = line
          issue
        end

        def create_report_from_errors(errors, filename)
          report = SvgConform::ConformanceReport.new
          report.filename = filename
          report.tool = 'svgcheck'
          report.timestamp = Time.now.iso8601
          report.valid = errors.empty?

          # Initialize summaries
          report.errors = SvgConform::IssueSummary.new
          report.errors.total_count = errors.length
          report.errors.by_requirement = {}
          report.errors.issues = errors

          report.warnings = SvgConform::IssueSummary.new
          report.warnings.total_count = 0
          report.warnings.by_requirement = {}
          report.warnings.issues = []

          # Group errors by requirement
          if errors.any?
            error_groups = errors.group_by(&:requirement_id)
            error_groups.each do |req_id, req_errors|
              report.errors.by_requirement[req_id] = req_errors.length
            end
          end

          report
        end

        def create_empty_report(filename)
          report = SvgConform::ConformanceReport.new
          report.filename = filename
          report.tool = 'svgcheck'
          report.timestamp = Time.now.iso8601
          report.valid = true

          report.errors = SvgConform::IssueSummary.new
          report.errors.total_count = 0
          report.errors.by_requirement = {}
          report.errors.issues = []

          report.warnings = SvgConform::IssueSummary.new
          report.warnings.total_count = 0
          report.warnings.by_requirement = {}
          report.warnings.issues = []

          report
        end
      end
    end
  end
end
