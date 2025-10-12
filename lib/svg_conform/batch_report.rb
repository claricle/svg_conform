# frozen_string_literal: true

require "lutaml/model"

module SvgConform
  # Result for a single file in batch processing
  class FileResult < Lutaml::Model::Serializable
    attribute :filename, :string
    attribute :original_path, :string
    attribute :valid_before, :boolean
    attribute :valid_after, :boolean
    attribute :errors_before, :integer
    attribute :errors_after, :integer
    attribute :remediated_path, :string
    attribute :status, :string # "valid", "remediated", "failed", "error"
    attribute :error_message, :string

    yaml do
      map "filename", to: :filename
      map "original_path", to: :original_path
      map "valid_before", to: :valid_before
      map "valid_after", to: :valid_after
      map "errors_before", to: :errors_before
      map "errors_after", to: :errors_after
      map "remediated_path", to: :remediated_path
      map "status", to: :status
      map "error_message", to: :error_message
    end
  end

  # Batch validation/remediation report
  class BatchReport < Lutaml::Model::Serializable
    attribute :directory, :string
    attribute :profile, :string
    attribute :timestamp, :string, default: -> { Time.now.iso8601 }
    attribute :total_files, :integer
    attribute :valid_before, :integer
    attribute :valid_after, :integer
    attribute :remediated, :integer
    attribute :failed, :integer
    attribute :success_rate, :float
    attribute :files, FileResult, collection: true, default: []
    attribute :manifest, :hash, default: {}

    yaml do
      map "directory", to: :directory
      map "profile", to: :profile
      map "timestamp", to: :timestamp
      map "total_files", to: :total_files
      map "valid_before", to: :valid_before
      map "valid_after", to: :valid_after
      map "remediated", to: :remediated
      map "failed", to: :failed
      map "success_rate", to: :success_rate
      map "files", to: :files
      map "manifest", to: :manifest
    end

    def calculate_statistics
      self.total_files = files.length
      self.valid_before = files.count(&:valid_before)
      self.valid_after = files.count(&:valid_after)
      self.remediated = files.count { |f| f.status == "remediated" }
      self.failed = files.count do |f|
        ["failed", "error"].include?(f.status)
      end
      self.success_rate = total_files.zero? ? 0.0 : (valid_after.to_f / total_files * 100).round(1)
    end
  end
end
