# frozen_string_literal: true

require "lutaml/model"
require "rainbow"

module SvgConform
  # Represents a single SVG file's quality analysis report.
  # Uses lutaml-model for YAML serialization and supports terminal rendering.
  #
  # @example YAML output
  #   report = analyzer.analyze_file('image.svg')
  #   puts report.to_yaml
  #
  # @example Terminal rendering
  #   puts report.render  # Colorful terminal output with emojis
  #
  class SvgQualityReport < Lutaml::Model::Serializable
    attribute :file_path, :string
    attribute :quality_score, :integer
    attribute :quality_level, :symbol
    attribute :error_count, :integer
    attribute :remediable_errors, :integer
    attribute :non_remediable_errors, :integer
    attribute :critical_errors, :integer
    attribute :high_errors, :integer
    attribute :medium_errors, :integer
    attribute :low_errors, :integer
    attribute :element_count, :integer
    attribute :file_size_kb, :float
    attribute :complexity_index, :float
    attribute :content_health, :symbol
    attribute :size_category, :symbol
    attribute :has_base64, :boolean
    attribute :has_foreign_ns, :boolean
    attribute :has_masks, :boolean
    attribute :has_clip_paths, :boolean
    attribute :has_external_refs, :boolean

    yaml do
      map "file_path", to: :file_path
      map "quality_score", to: :quality_score
      map "quality_level", to: :quality_level
      map "error_count", to: :error_count
      map "remediable_errors", to: :remediable_errors
      map "non_remediable_errors", to: :non_remediable_errors
      map "critical_errors", to: :critical_errors
      map "high_errors", to: :high_errors
      map "medium_errors", to: :medium_errors
      map "low_errors", to: :low_errors
      map "element_count", to: :element_count
      map "file_size_kb", to: :file_size_kb
      map "complexity_index", to: :complexity_index
      map "content_health", to: :content_health
      map "size_category", to: :size_category
      map "has_base64", to: :has_base64
      map "has_foreign_ns", to: :has_foreign_ns
      map "has_masks", to: :has_masks
      map "has_clip_paths", to: :has_clip_paths
      map "has_external_refs", to: :has_external_refs
    end

    # Render report as colorful terminal output
    #
    # @param theme [Hash] Theme configuration for colors/emojis
    # @return [String] ANSI-colored terminal output
    def render(theme: TerminalTheme.default)
      lines = []

      # Header with level emoji
      lines << theme.header("📊 SVG Quality Report: #{File.basename(file_path)}")
      lines << ""

      # Quality score with color
      lines << "  #{theme.level_emoji(quality_level)} Quality: #{theme.wrap_with_level(
        quality_score.to_s, quality_level
      )} (#{theme.level_name(quality_level)})"

      # Content health
      health_emoji = health_emoji_for(content_health)
      lines << "  #{health_emoji} Content Health: #{content_health}"

      # File info
      lines << ""
      lines << "  📁 File: #{file_size_kb.round(2)} KB (#{size_category})"
      lines << "  📐 Elements: #{element_count}"
      lines << "  🔢 Complexity: #{complexity_index.round(1)}/10"

      # Errors breakdown
      lines << ""
      lines << theme.separator("Errors: #{error_count}")
      lines << "  🔧 Remediable: #{theme.wrap_with_severity(
        remediable_errors.to_s, :remediable
      )}"
      lines << "  ⚠️  Non-remediable: #{theme.wrap_with_severity(
        non_remediable_errors.to_s, :non_remediable
      )}"

      if error_count.positive?
        lines << ""
        lines << "  Breakdown:"
        if critical_errors.positive?
          lines << "    #{theme.wrap_with_severity(
            "● Critical: #{critical_errors}", :critical
          )}"
        end
        if high_errors.positive?
          lines << "    #{theme.wrap_with_severity("● High: #{high_errors}",
                                                   :high)}"
        end
        if medium_errors.positive?
          lines << "    #{theme.wrap_with_severity("● Medium: #{medium_errors}",
                                                   :medium)}"
        end
        if low_errors.positive?
          lines << "    #{theme.wrap_with_severity("● Low: #{low_errors}",
                                                   :low)}"
        end
      end

      # Features
      features = []
      features << "Base64" if has_base64
      features << "Foreign NS" if has_foreign_ns
      features << "Masks" if has_masks
      features << "ClipPaths" if has_clip_paths
      features << "External Refs" if has_external_refs

      if features.any?
        lines << ""
        lines << "  ✨ Features: #{features.join(', ')}"
      end

      lines << ""
      lines.join("\n")
    end

    private

    def health_emoji_for(health)
      case health
      when :good then "✅"
      when :minor_issues then "⚠️"
      when :moderate_issues then "🔶"
      when :severe_issues then "🔴"
      else "❓"
      end
    end
  end

  # Represents batch quality analysis summary/report.
  #
  # @example YAML output
  #   batch = analyzer.analyze_directory('./svgs')
  #   puts batch.to_yaml
  #
  # @example Terminal rendering
  #   puts batch.render  # Summary with distribution chart
  #
  class SvgQualityBatchReport < Lutaml::Model::Serializable
    attribute :total_files, :integer
    attribute :successful, :integer
    attribute :failed, :integer
    attribute :avg_quality_score, :float
    attribute :quality_distribution, :hash
    attribute :avg_error_count, :float
    attribute :total_errors, :integer
    attribute :remediable_errors, :integer
    attribute :non_remediable_errors, :integer
    attribute :reports, SvgQualityReport, collection: true

    yaml do
      map "total_files", to: :total_files
      map "successful", to: :successful
      map "failed", to: :failed
      map "avg_quality_score", to: :avg_quality_score
      map "quality_distribution", to: :quality_distribution
      map "avg_error_count", to: :avg_error_count
      map "total_errors", to: :total_errors
      map "remediable_errors", to: :remediable_errors
      map "non_remediable_errors", to: :non_remediable_errors
      map "reports", to: :reports
    end

    # Render batch report as colorful terminal output
    #
    # @param theme [Hash] Theme configuration
    # @return [String] ANSI-colored terminal output
    def render(theme: TerminalTheme.default)
      lines = []

      lines << theme.header("📊 SVG Quality Batch Report")
      lines << ""
      lines << "  📁 Total Files: #{total_files}"
      lines << "  ✅ Successful: #{successful}"
      lines << "  ❌ Failed: #{failed}" if failed.positive?
      lines << ""

      # Quality distribution chart
      lines << theme.separator("Quality Distribution")
      lines << ""
      render_distribution_chart(lines, theme)
      lines << ""

      # Summary stats
      lines << theme.separator("Summary")
      lines << ""
      lines << "  📈 Average Quality Score: #{theme.wrap_with_level(
        avg_quality_score.round(1).to_s, average_level
      )}/100"
      lines << "  📊 Average Errors/File: #{avg_error_count.round(1)}"
      lines << ""

      # Error breakdown
      lines << "  🔧 Total Remediable: #{theme.wrap_with_severity(
        remediable_errors.to_s, :remediable
      )}"
      lines << "  ⚠️  Total Non-remediable: #{theme.wrap_with_severity(
        non_remediable_errors.to_s, :non_remediable
      )}"
      lines << ""

      lines.join("\n")
    end

    private

    def average_level
      case avg_quality_score
      when 90..100 then :excellent
      when 70..89 then :good
      when 50..69 then :fair
      when 30..49 then :poor
      else :critical
      end
    end

    def render_distribution_chart(lines, theme)
      max_count = quality_distribution.values.max || 1
      bar_width = 40

      %i[excellent good fair poor critical].each do |level|
        count = quality_distribution[level.to_s] || quality_distribution[level] || 0
        percentage = (count.to_f / total_files * 100).round(1)
        bar_fill = (count.to_f / max_count * bar_width).round

        bar = ("█" * bar_fill) + ("░" * (bar_width - bar_fill))
        label = "#{theme.level_emoji(level)} #{level.to_s.upcase.ljust(10)}"
        colored_line = theme.wrap_with_level(
          "#{label} #{bar} #{count.to_s.rjust(4)} (#{percentage}%)", level
        )

        lines << "  #{colored_line}"
      end
    end
  end

  # Terminal theme configuration for colorful output
  #
  # @example Custom theme
  #   custom = TerminalTheme.new(
  #     colors: { excellent: :green, good: :cyan, ... },
  #     emojis: { excellent: "✨", good: "👍", ... }
  #   )
  #
  class TerminalTheme
    attr_reader :colors, :emojis

    def initialize(colors: default_colors, emojis: default_emojis)
      @colors = colors
      @emojis = emojis
    end

    def self.default
      @default ||= new
    end

    def wrap(text, color)
      Rainbow(text).color(color)
    end

    def wrap_with_level(text, level)
      Rainbow(text).color(color_for_level(level))
    end

    def wrap_with_severity(text, severity)
      Rainbow(text).color(color_for_severity(severity))
    end

    def color_for_level(level)
      @colors[level] || :white
    end

    def color_for_severity(severity)
      case severity
      when :critical then :red
      when :high, :non_remediable then :yellow
      when :medium then :magenta
      when :low then :cyan
      when :remediable then :green
      else :white
      end
    end

    def level_emoji(level)
      @emojis[level] || "•"
    end

    def level_name(level)
      level.to_s.upcase
    end

    def header(text)
      Rainbow(text).color(:blue)
    end

    def separator(text)
      Rainbow(text).faint
    end

    private

    def default_colors
      {
        excellent: :green,
        good: :cyan,
        fair: :yellow,
        poor: :magenta,
        critical: :red,
      }
    end

    def default_emojis
      {
        excellent: "✨",
        good: "👍",
        fair: "⚠️",
        poor: "😟",
        critical: "💥",
      }
    end
  end
end
