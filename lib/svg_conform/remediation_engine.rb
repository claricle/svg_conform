# frozen_string_literal: true

module SvgConform
  # Engine for applying remediations to SVG documents based on validation failures
  class RemediationEngine
    attr_reader :profile, :results

    def initialize(profile)
      @profile = profile
      @results = []
    end

    # Apply remediations for failed requirements
    def apply_remediations(document, validation_result)
      @results.clear

      # Group failed requirements by their remediations
      remediation_groups = group_requirements_by_remediations(validation_result.failed_requirements)

      # Apply each remediation only once, even if it targets multiple failed requirements
      remediation_groups.each do |remediation, failed_requirements|
        result = remediation.execute(document, failed_requirements)
        @results << result
      end

      @results
    end

    # Get remediations that would apply to given failed requirements
    def applicable_remediations(failed_requirements)
      failed_requirement_ids = failed_requirements.map do |req|
        req.requirement_id || req.rule&.id
      end

      @profile.remediations.select do |remediation|
        remediation.targets.any? do |req_id|
          failed_requirement_ids.include?(req_id)
        end
      end
    end

    # Check if any remediations are available for the profile
    def has_remediations?
      @profile.remediation_count.positive?
    end

    # Get summary of remediation results
    def summary
      return "No remediations applied" if @results.empty?

      successful = @results.count(&:success?)
      failed = @results.count(&:failure?)
      total_changes = @results.sum(&:changes_count)

      "Applied #{successful} remediations successfully, #{failed} failed. Total changes: #{total_changes}"
    end

    # Get successful remediation results
    def successful_results
      @results.select(&:success?)
    end

    # Get failed remediation results
    def failed_results
      @results.select(&:failure?)
    end

    # Get total number of changes made
    def total_changes
      @results.sum(&:changes_count)
    end

    private

    # Group failed requirements by the remediations that target them
    def group_requirements_by_remediations(failed_requirements)
      groups = {}

      @profile.remediations.each do |remediation|
        # Find failed requirements that this remediation targets
        targeted_failures = failed_requirements.select do |failure|
          remediation.targets.include?(failure.requirement_id)
        end

        # Only include remediations that have applicable failures
        groups[remediation] = targeted_failures unless targeted_failures.empty?
      end

      groups
    end
  end
end
