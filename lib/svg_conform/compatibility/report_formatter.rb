# frozen_string_literal: true

require "paint"

module SvgConform
  module Compatibility
    # Handles formatting and display of compatibility analysis results
    class ReportFormatter
      def initialize(context)
        @context = context
      end

      def display_single_file_result(result)
        if @context.semantic_analysis?
          display_semantic_single_result(result)
        else
          display_basic_single_result(result)
        end
      end

      def display_batch_results(results)
        if @context.semantic_analysis?
          display_semantic_batch_results(results)
        else
          display_basic_batch_results(results)
        end
      end

      def write_output_file(results)
        return unless @context.file_output?

        content = generate_output_content(results)
        File.write(@context.output_file, content)
        puts "📄 Results written to: #{@context.output_file}"
      end

      private

      def display_semantic_single_result(result)
        display_file_header(result.filename)
        display_semantic_validation_section(result)
        display_semantic_repair_section(result) if @context.repair_mode?
        display_xml_equivalence_section(result) if result.xml_equivalence
      end

      def display_basic_single_result(result)
        display_file_header(result.filename)
        display_basic_validation_section(result)
        display_basic_repair_section(result) if @context.repair_mode?
      end

      def display_semantic_batch_results(results)
        display_batch_header(results.length)
        display_semantic_summary_table(results)
        display_semantic_batch_statistics(results)
      end

      def display_basic_batch_results(results)
        display_batch_header(results.length)
        display_basic_summary_table(results)
        display_basic_batch_statistics(results)
      end

      def display_file_header(filename)
        mode_icon = @context.repair_mode? ? "🔧" : "📋"
        mode_text = @context.repair_mode? ? "Repair Analysis" : "Analysis"
        analysis_type = @context.semantic_analysis? ? "Semantic" : "Basic"

        puts Paint["#{mode_icon} #{analysis_type} #{mode_text}: #{filename}",
                   :cyan, :bold]
        puts "=" * 60
      end

      def display_batch_header(file_count)
        mode_icon = @context.repair_mode? ? "🔧" : "📋"
        mode_text = @context.repair_mode? ? "Repair Analysis" : "Analysis"
        analysis_type = @context.semantic_analysis? ? "Semantic" : "Basic"

        puts Paint["#{mode_icon} #{analysis_type} Batch #{mode_text} (#{file_count} files)",
                   :cyan, :bold]
        puts "=" * 80
      end

      def display_semantic_validation_section(result)
        return unless result.validation_comparison

        puts Paint["📊 Validation Comparison:", :blue, :bold]

        score = result.compatibility_score
        score_color = if score >= 90
                        :green
                      else
                        score >= 70 ? :yellow : :red
                      end
        puts "  Compatibility Score: #{Paint[format('%.1f%%', score),
                                             score_color, :bold]}"

        validity_status = result.validity_match? ? "✅ Match" : "❌ Mismatch"
        puts "  Validity Match: #{validity_status}"
        puts "  SvgConform Valid: #{result.svg_conform_valid? ? '✅' : '❌'}"
        puts "  Svgcheck Valid: #{result.svgcheck_valid? ? '✅' : '❌'}"
        puts
      end

      def display_semantic_repair_section(result)
        return unless result.validation_comparison

        puts Paint["🔧 Repair Results:", :blue, :bold]

        if result.successful_remediation?
          puts "  Remediation: #{Paint['✅ Successful', :green, :bold]}"
        else
          puts "  Remediation: #{Paint['❌ Failed', :red, :bold]}"
        end

        if result.content_comparison
          equivalence = result.content_equivalence_score
          equiv_color = if equivalence >= 90
                          :green
                        else
                          equivalence >= 70 ? :yellow : :red
                        end
          puts "  Content Equivalence: #{Paint[format('%.1f%%', equivalence),
                                               equiv_color, :bold]}"
        end
        puts
      end

      def display_xml_equivalence_section(result)
        puts Paint["🔍 XML Equivalence:", :blue, :bold]

        if result.xml_error
          puts "  Status: #{Paint['❌ Error', :red, :bold]}"
          puts "  Error: #{result.xml_error}"
        elsif result.xml_equivalent?
          puts "  Status: #{Paint['✅ Equivalent', :green, :bold]}"
        else
          puts "  Status: #{Paint['❌ Different', :red, :bold]}"
          puts "  Differences: #{result.xml_differences.length}"
        end
        puts
      end

      def display_basic_validation_section(result)
        puts Paint["📊 Validation Results:", :blue, :bold]
        puts "  SvgConform Valid: #{result.svg_conform_valid? ? '✅' : '❌'}"
        puts "  Svgcheck Valid: #{result.svgcheck_valid? ? '✅' : '❌'}"
        puts "  Validity Match: #{result.validity_match? ? '✅' : '❌'}"
        puts
      end

      def display_basic_repair_section(result)
        puts Paint["🔧 Repair Results:", :blue, :bold]

        if result.successful_remediation?
          puts "  Remediation: #{Paint['✅ Successful', :green, :bold]}"
          puts "  Issues Fixed: #{result.issues_fixed}"
          puts "  Remediations Applied: #{result.remediations_applied}"
        else
          puts "  Remediation: #{Paint['❌ Failed', :red, :bold]}"
        end
        puts
      end

      def display_semantic_summary_table(results)
        puts Paint["📊 Summary Table:", :blue, :bold]
        puts

        header = "File                      Compatibility    Valid   SvgConform     Svgcheck"
        puts Paint[header, :white, :bold]
        puts "-" * 70

        results.each do |result|
          score = format("%.1f%%", result.compatibility_score)
          score_color = if result.compatibility_score >= 90
                          :green
                        else
                          result.compatibility_score >= 70 ? :yellow : :red
                        end

          validity = result.validity_match? ? "✅" : "❌"
          svg_conform = result.svg_conform_valid? ? "✅" : "❌"
          svgcheck = result.svgcheck_valid? ? "✅" : "❌"

          row = format("%-25s %12s %8s %12s %12s",
                       result.filename.truncate(23),
                       Paint[score, score_color],
                       validity,
                       svg_conform,
                       svgcheck)
          puts row
        end
        puts
      end

      def display_basic_summary_table(results)
        puts Paint["📊 Summary Table:", :blue, :bold]
        puts

        header = "File                         Valid   SvgConform     Svgcheck   Errors"
        puts Paint[header, :white, :bold]
        puts "-" * 66

        results.each do |result|
          validity = result.validity_match? ? "✅" : "❌"
          svg_conform = result.svg_conform_valid? ? "✅" : "❌"
          svgcheck = result.svgcheck_valid? ? "✅" : "❌"
          errors = result.error_count

          row = format("%-25s %8s %12s %12s %8d",
                       result.filename.truncate(23),
                       validity,
                       svg_conform,
                       svgcheck,
                       errors)
          puts row
        end
        puts
      end

      def display_semantic_batch_statistics(results)
        puts Paint["📈 Statistics:", :blue, :bold]

        avg_compatibility = results.sum(&:compatibility_score) / results.length
        validity_matches = results.count(&:validity_match?)
        successful_remediations = results.count(&:successful_remediation?) if @context.repair_mode?

        score_color = if avg_compatibility >= 90
                        :green
                      else
                        avg_compatibility >= 70 ? :yellow : :red
                      end
        puts "  Average Compatibility: #{Paint[format('%.1f%%', avg_compatibility),
                                               score_color, :bold]}"
        puts "  Validity Matches: #{validity_matches}/#{results.length} (#{format('%.1f%%',
                                                                                  validity_matches * 100.0 / results.length)})"

        if @context.repair_mode?
          puts "  Successful Remediations: #{successful_remediations}/#{results.length} (#{format('%.1f%%',
                                                                                                  successful_remediations * 100.0 / results.length)})"
        end
        puts
      end

      def display_basic_batch_statistics(results)
        puts Paint["📈 Statistics:", :blue, :bold]

        validity_matches = results.count(&:validity_match?)
        successful_remediations = results.count(&:successful_remediation?) if @context.repair_mode?
        total_errors = results.sum(&:error_count)

        puts "  Validity Matches: #{validity_matches}/#{results.length} (#{format('%.1f%%',
                                                                                  validity_matches * 100.0 / results.length)})"
        puts "  Total Errors: #{total_errors}"

        if @context.repair_mode?
          puts "  Successful Remediations: #{successful_remediations}/#{results.length} (#{format('%.1f%%',
                                                                                                  successful_remediations * 100.0 / results.length)})"
        end
        puts
      end

      def generate_output_content(results)
        content = []
        content << "# Compatibility Analysis Results"
        content << ""
        content << "Analysis Type: #{@context.semantic_analysis? ? 'Semantic' : 'Basic'}"
        content << "Mode: #{@context.mode.to_s.capitalize}"
        content << "Profile: #{@context.profile}"
        content << "Generated: #{Time.now}"
        content << ""

        if results.is_a?(Array)
          generate_batch_output_content(content, results)
        else
          generate_single_output_content(content, results)
        end

        content.join("\n")
      end

      def generate_batch_output_content(content, results)
        content << "## Summary"
        content << ""

        if @context.semantic_analysis?
          avg_compatibility = results.sum(&:compatibility_score) / results.length
          content << "Average Compatibility: #{format('%.1f%%',
                                                      avg_compatibility)}"
        end

        validity_matches = results.count(&:validity_match?)
        content << "Validity Matches: #{validity_matches}/#{results.length}"

        if @context.repair_mode?
          successful_remediations = results.count(&:successful_remediation?)
          content << "Successful Remediations: #{successful_remediations}/#{results.length}"
        end

        content << ""
        content << "## Individual Results"
        content << ""

        results.each do |result|
          content << "### #{result.filename}"
          content << ""
          add_result_details(content, result)
          content << ""
        end
      end

      def generate_single_output_content(content, result)
        content << "## #{result.filename}"
        content << ""
        add_result_details(content, result)
      end

      def add_result_details(content, result)
        if @context.semantic_analysis?
          content << "Compatibility Score: #{format('%.1f%%',
                                                    result.compatibility_score)}"
        end

        content << "Validity Match: #{result.validity_match?}"
        content << "SvgConform Valid: #{result.svg_conform_valid?}"
        content << "Svgcheck Valid: #{result.svgcheck_valid?}"

        return unless @context.repair_mode?

        content << "Successful Remediation: #{result.successful_remediation?}"

        if result.content_comparison
          content << "Content Equivalence: #{format('%.1f%%',
                                                    result.content_equivalence_score)}"
        end

        return unless result.xml_equivalence

        content << "XML Equivalent: #{result.xml_equivalent?}"
        return unless result.xml_error

        content << "XML Error: #{result.xml_error}"
      end
    end
  end
end

# String extension for truncation
class String
  def truncate(length)
    if self.length > length
      "#{self[0..(length - 4)]}..."
    else
      self
    end
  end
end
