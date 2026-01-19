# frozen_string_literal: true

require "nokogiri"
require_relative "semantic_extractor"
require_relative "normalizer"

module SvgConform
  module Comparison
    # Validation result comparison engine
    # Compares validation reports between svg_conform and svgcheck
    class ValidationComparator
      include SemanticExtractor
      include Normalizer

      # Compare validation results semantically
      # @param svg_conform_report [Object] svg_conform validation report
      # @param svgcheck_report [Object] svgcheck validation report
      # @return [Hash] comparison results with compatibility metrics
      def compare(svg_conform_report, svgcheck_report)
        # Extract semantic features from both reports
        svg_conform_features = extract_validation_features(svg_conform_report)
        svgcheck_features = extract_validation_features(svgcheck_report)

        # Detect repair mode (both tools report valid=true)
        repair_mode = svg_conform_features[:valid] && svgcheck_features[:valid]

        # Detect mixed mode (one valid, one invalid)
        mixed_mode = svg_conform_features[:valid] != svgcheck_features[:valid]

        # Compare features semantically
        {
          overall_validity: compare_validity(svg_conform_features[:valid],
                                             svgcheck_features[:valid]),
          requirement_coverage: compare_requirement_coverage(svg_conform_features[:requirements],
                                                             svgcheck_features[:requirements]),
          semantic_issues: compare_semantic_issues(svg_conform_features[:issues], svgcheck_features[:issues],
                                                   repair_mode, mixed_mode),
          detailed_mapping: create_detailed_mapping(svg_conform_features[:issues], svgcheck_features[:issues],
                                                    repair_mode, mixed_mode),
          repair_mode: repair_mode,
          mixed_mode: mixed_mode,
        }.tap do |comparison|
          # Add validity_match for compatibility
          comparison[:validity_match] = comparison[:overall_validity][:match]

          # Calculate overall compatibility score
          comparison[:compatibility_score] = calculate_compatibility_score(comparison)
        end
      end

      # Extract validation features for semantic comparison
      # @param report [Object] validation report
      # @return [Hash] extracted validation features
      def extract_validation_features(report)
        # Extract ALL issues (errors, warnings, infos) for semantic comparison
        issues = []

        issues.concat(report.errors.issues) if report.respond_to?(:errors) && report.errors.respond_to?(:issues)

        # For svgcheck reports, also include warnings and infos if available
        issues.concat(report.warnings.issues) if report.respond_to?(:warnings) && report.warnings.respond_to?(:issues)

        # If the report has a direct issues method, use that
        issues = report.issues if issues.empty? && report.respond_to?(:issues)

        {
          valid: report.respond_to?(:valid) ? report.valid : false,
          requirements: extract_requirement_types(issues),
          issues: group_issues_semantically(issues),
        }
      end

      # Extract requirement types from issues
      # @param issues [Array] list of issue objects
      # @return [Hash] requirement type counts
      def extract_requirement_types(issues)
        requirement_counts = {}
        issues.each do |issue|
          req_id = issue.respond_to?(:requirement_id) ? issue.requirement_id :
                   (issue.respond_to?(:requirement) ? issue.requirement&.to_s : "unknown")
          requirement_counts[req_id] ||= 0
          requirement_counts[req_id] += 1
        end
        requirement_counts
      end

      # Compare validity between two reports
      # @param valid1 [Boolean] first report validity
      # @param valid2 [Boolean] second report validity
      # @return [Hash] validity comparison result
      def compare_validity(valid1, valid2)
        {
          match: valid1 == valid2,
          valid1: valid1,
          valid2: valid2,
          both_valid: valid1 && valid2,
          both_invalid: !valid1 && !valid2,
        }
      end

      # Compare requirement coverage between two reports
      # @param reqs1 [Hash] first report requirements
      # @param reqs2 [Hash] second report requirements
      # @return [Hash] requirement coverage comparison
      def compare_requirement_coverage(reqs1, reqs2)
        all_reqs = (reqs1.keys | reqs2.keys).sort

        {
          common: all_reqs.select { |r| reqs1.key?(r) && reqs2.key?(r) },
          only_in_first: all_reqs.select { |r| reqs1.key?(r) && !reqs2.key?(r) },
          only_in_second: all_reqs.select { |r| !reqs1.key?(r) && reqs2.key?(r) },
          count_difference: (reqs1.values.sum || 0) - (reqs2.values.sum || 0),
        }
      end

      # Compare semantic issues between two reports
      # @param issues1 [Hash] first report grouped issues
      # @param issues2 [Hash] second report grouped issues
      # @param repair_mode [Boolean] whether both reports are valid
      # @param mixed_mode [Boolean] whether validity differs
      # @return [Hash] semantic issues comparison
      def compare_semantic_issues(issues1, issues2, repair_mode, mixed_mode)
        {
          category_match: compare_issue_categories(issues1, issues2),
          count_difference: (issues1[:total_count] || 0) - (issues2[:total_count] || 0),
          severity_match: compare_severity_distribution(issues1, issues2),
          repair_mode_discrepancy: detect_repair_mode_discrepancies(issues1, issues2, repair_mode),
          mixed_mode_impact: calculate_mixed_mode_impact(issues1, issues2, mixed_mode),
        }
      end

      # Create detailed mapping between issues
      # @param issues1 [Hash] first report grouped issues
      # @param issues2 [Hash] second report grouped issues
      # @param repair_mode [Boolean] whether both reports are valid
      # @param mixed_mode [Boolean] whether validity differs
      # @return [Hash] detailed issue mapping
      def create_detailed_mapping(issues1, issues2, repair_mode, mixed_mode)
        all_categories = (issues1.keys | issues2.keys) - [:total_count]

        all_categories.each_with_object({}) do |category, mapping|
          issues1_count = issues1[category]&.length || 0
          issues2_count = issues2[category]&.length || 0

          mapping[category] = {
            count1: issues1_count,
            count2: issues2_count,
            difference: issues1_count - issues2_count,
            match: issues1_count == issues2_count,
          }
        end
      end

      # Calculate compatibility score from comparison
      # @param comparison [Hash] comparison results
      # @return [Float] compatibility score (0.0 to 1.0)
      def calculate_compatibility_score(comparison)
        # Start with base score
        score = 1.0

        # Reduce based on overall validity match
        score -= 0.5 unless comparison[:overall_validity][:match]

        # Reduce based on semantic issues
        issues = comparison[:semantic_issues]
        score -= 0.2 unless issues[:category_match]
        score -= 0.1 * (issues[:count_difference].abs.to_f / 100).clamp(0, 1)

        # Adjust for repair mode
        if comparison[:repair_mode]
          score = calculate_mixed_mode_compatibility_score(comparison)
        end

        # Adjust for mixed mode
        if comparison[:mixed_mode]
          score = calculate_mixed_mode_compatibility_score(comparison)
        end

        score.clamp(0.0, 1.0)
      end

      # Calculate compatibility score for mixed mode scenarios
      # @param comparison [Hash] comparison results
      # @return [Float] compatibility score
      def calculate_mixed_mode_compatibility_score(comparison)
        # In mixed mode, focus on requirement coverage match
        coverage = comparison[:requirement_coverage]
        common_reqs = coverage[:common].length
        total_reqs = (coverage[:common] + coverage[:only_in_first] + coverage[:only_in_second]).length

        return 0.0 if total_reqs.zero?

        # Base score on requirement overlap
        score = common_reqs.to_f / total_reqs

        # Adjust for semantic category match
        score *= 0.9 unless comparison[:semantic_issues][:category_match]

        score.clamp(0.0, 1.0)
      end

      private

      # Compare issue categories between two reports
      # @param issues1 [Hash] first report grouped issues
      # @param issues2 [Hash] second report grouped issues
      # @return [Boolean] whether categories match
      def compare_issue_categories(issues1, issues2)
        cats1 = (issues1.keys - [:total_count]).sort
        cats2 = (issues2.keys - [:total_count]).sort
        cats1 == cats2
      end

      # Compare severity distribution between two reports
      # @param issues1 [Hash] first report grouped issues
      # @param issues2 [Hash] second report grouped issues
      # @return [Boolean] whether severity distribution matches
      def compare_severity_distribution(issues1, issues2)
        # Simplified severity comparison
        count1 = issues1[:total_count] || 0
        count2 = issues2[:total_count] || 0
        count1 == count2
      end

      # Detect repair mode discrepancies
      # @param issues1 [Hash] first report grouped issues
      # @param issues2 [Hash] second report grouped issues
      # @param repair_mode [Boolean] expected repair mode
      # @return [Hash] repair mode discrepancy info
      def detect_repair_mode_discrepancies(issues1, issues2, repair_mode)
        {
          expected_repair: repair_mode,
          actual_both_empty: (issues1[:total_count] || 0) == 0 && (issues2[:total_count] || 0) == 0,
          discrepancy: repair_mode && ((issues1[:total_count] || 0) > 0 || (issues2[:total_count] || 0) > 0),
        }
      end

      # Calculate mixed mode impact
      # @param issues1 [Hash] first report grouped issues
      # @param issues2 [Hash] second report grouped issues
      # @param mixed_mode [Boolean] whether in mixed mode
      # @return [Hash] mixed mode impact info
      def calculate_mixed_mode_impact(issues1, issues2, mixed_mode)
        return { impact: :none } unless mixed_mode

        {
          impact: :partial,
          has_issues_in_valid: (issues1[:total_count] || 0) > 0 || (issues2[:total_count] || 0) > 0,
        }
      end
    end
  end
end
