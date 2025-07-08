# frozen_string_literal: true

module SvgConform
  # Result object for remediation operations
  class RemediationResult
    attr_reader :remediation_id, :success, :failed_requirements, :message, :changes_made, :error

    def initialize(remediation_id:, success:, failed_requirements:, message: nil, changes_made: [], error: nil)
      @remediation_id = remediation_id
      @success = success
      @failed_requirements = failed_requirements
      @message = message
      @changes_made = changes_made || []
      @error = error
    end

    def success?
      @success
    end

    def failure?
      !@success
    end

    def changes_count
      @changes_made.size
    end

    def to_s
      status = success? ? 'SUCCESS' : 'FAILURE'
      "#{@remediation_id}: #{status} - #{@message}"
    end
  end
end
