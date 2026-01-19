# frozen_string_literal: true

require "table_tennis"
require "paint"

module SvgConform
  module Comparison
    # Table formatting utilities for displaying comparison results
    #
    # This module handles all display/presentation logic for report comparisons,
    # separating formatting concerns from core comparison logic.
    #
    # The module uses the TableTennis gem for table rendering and Paint for
    # terminal color formatting.
    #
    # @note This module is intended to be mixed into classes that need
    #       table display capabilities.
    module TableFormatter
      # Display single file comparison result
      #
      # @param result [Hash] comparison result hash
      # @option result [String] :filename the file name
      # @option result [Boolean] :svg_conform_valid SvgConform validity
      # @option result [Boolean] :svgcheck_valid svgcheck validity
      # @option result [Boolean] :valid_match whether validity matches
      # @option result [Integer] :svg_conform_errors SvgConform error count
      # @option result [Integer] :svgcheck_errors svgcheck error count
      # @option result [Boolean] :errors_match whether error counts match
      # @option result [Integer] :svg_conform_error_types SvgConform error types count
      # @option result [Integer] :svgcheck_error_types svgcheck error types count
      # @option result [Boolean] :error_types_match whether error types match
      # @option result [Hash] :semantic_mapping semantic error type mapping
      def display_single_file_result(result)
        return unless result

        filename = result[:filename]

        puts "\n#{Paint['=' * 80, :cyan]}"
        puts Paint["📊 REPORT COMPARISON: #{filename}", :blue, :bold]
        puts Paint["=" * 80, :cyan]

        # Summary table
        headers = ["Metric", "SvgConform", "svgcheck", "Match?"]
        rows = [
          ["Valid", result[:svg_conform_valid], result[:svgcheck_valid],
           result[:valid_match] ? "✓" : "✗"],
          ["Total Errors", result[:svg_conform_errors], result[:svgcheck_errors],
           result[:errors_match] ? "✓" : "✗"],
          ["Error Types", result[:svg_conform_error_types], result[:svgcheck_error_types],
           result[:error_types_match] ? "✓" : "✗"],
        ]

        puts "\nSUMMARY:"
        render_gh_style_table(headers, rows)

        # Semantic error mapping table
        if result[:semantic_mapping]&.any?
          headers = ["Error Type", "SvgConform Count", "svgcheck Count",
                     "Status"]
          rows = []

          result[:semantic_mapping].each do |error_type, counts|
            svg_count = counts[:svg_conform]
            svgcheck_count = counts[:svgcheck]
            status = if svg_count == svgcheck_count && svg_count.positive?
                       "✓ MATCH"
                     elsif svg_count == svgcheck_count && svg_count.zero?
                       "✓ BOTH NONE"
                     elsif svg_count > svgcheck_count
                       "⚠ MISMATCH"
                     elsif svg_count < svgcheck_count
                       "⚠ MISMATCH"
                     else
                       "? UNKNOWN"
                     end

            rows << [error_type, svg_count, svgcheck_count, status]
          end

          # Determine overall coverage status
          coverage_status = determine_coverage_status(result[:semantic_mapping])

          puts "\nSEMANTIC ERROR MAPPING: #{coverage_status}"
          render_gh_style_table(headers, rows)
        end

        # Display requirement-based mapping
        display_requirement_mapping(result)
      end

      # Display summary table for report comparison
      #
      # @param svg_conform_report [ConformanceReport] SvgConform validation report
      # @param svgcheck_report [ConformanceReport] svgcheck validation report
      def display_summary_table(svg_conform_report, svgcheck_report)
        headers = ["Metric", "SvgConform", "svgcheck", "Match?"]
        rows = [
          ["Valid", svg_conform_report.valid, svgcheck_report.valid,
           match_status(svg_conform_report.valid, svgcheck_report.valid)],
          ["Total Errors", svg_conform_report.errors.total_count, svgcheck_report.errors.total_count,
           match_status(svg_conform_report.errors.total_count, svgcheck_report.errors.total_count)],
          ["Error Types", svg_conform_report.errors.by_requirement.keys.length,
           svgcheck_report.errors.by_requirement.keys.length, match_status(svg_conform_report.errors.by_requirement.keys.length, svgcheck_report.errors.by_requirement.keys.length)],
        ]

        puts "\nSUMMARY:"
        render_gh_style_table(headers, rows)
      end

      # Display error mapping table comparing semantic error groups
      #
      # @param svg_conform_report [ConformanceReport] SvgConform validation report
      # @param svgcheck_report [ConformanceReport] svgcheck validation report
      def display_error_mapping_table(svg_conform_report, svgcheck_report)
        # Group errors by semantic meaning for comparison
        svg_conform_errors = SemanticExtractor.group_issues_semantically(svg_conform_report.errors.issues)
        svgcheck_errors = SemanticExtractor.group_issues_semantically(svgcheck_report.errors.issues)

        # Create mapping table
        headers = ["Error Type", "SvgConform Count", "svgcheck Count", "Status"]
        rows = []

        # All unique error types
        all_error_types = (svg_conform_errors.keys + svgcheck_errors.keys).uniq.sort

        all_error_types.each do |error_type|
          svg_count = svg_conform_errors[error_type] || 0
          svgcheck_count = svgcheck_errors[error_type] || 0
          status = if svg_count == svgcheck_count && svg_count.positive?
                     "✓ MATCH"
                   elsif svg_count == svgcheck_count && svg_count.zero?
                     "✓ BOTH NONE"
                   elsif svg_count > svgcheck_count
                     "⚠ EXTRA"
                   elsif svg_count < svgcheck_count
                     "⚠ MISSING"
                   else
                     "? UNKNOWN"
                   end

          rows << [error_type, svg_count, svgcheck_count, status]
        end

        puts "\nSEMANTIC ERROR MAPPING:"
        render_gh_style_table(headers, rows)
      end

      # Display requirement-based error mapping with colors
      #
      # @param result [Hash] comparison result hash
      def display_requirement_mapping(result)
        # Get the original reports to access detailed error information
        filename = result[:filename]

        begin
          # Load reports again to get detailed error information
          svgcheck_report_path = File.join(@reports_dir,
                                           "#{filename}.svgcheck.yaml")
          # Use the new external checker parser
          parser = SvgConform::ExternalCheckers::Svgcheck::Parser.new
          error_content = File.read(svgcheck_report_path)
          svgcheck_report = parser.parse(error_content, nil, filename: filename)

          # Generate SvgConform report
          validator = SvgConform::Validator.new
          svg_file_path = "svgcheck/svgcheck/Tests/#{filename}"
          svg_content = File.read(svg_file_path)
          validation_result = validator.validate(svg_content, profile: @profile)
          svg_conform_report = SvgConform::ConformanceReport.from_svg_conform_result(filename, validation_result,
                                                                                     profile: @profile, use_svgcheck_mapping: true)

          # Group errors by requirement
          svg_conform_by_requirement = group_errors_by_requirement(svg_conform_report.errors.issues)
          svgcheck_by_requirement = group_errors_by_requirement(svgcheck_report.errors.issues)

          # Identify unmapped svgcheck errors
          unmapped_svgcheck_errors = identify_unmapped_svgcheck_errors(
            svgcheck_report, svg_conform_report
          )

          # Get all requirements that have errors in either system
          all_requirements = (svg_conform_by_requirement.keys + svgcheck_by_requirement.keys).uniq.sort

          if all_requirements.any?
            puts "\n#{Paint['🔍 REQUIREMENT MAPPING:', :blue, :bold]}"

            all_requirements.each do |requirement|
              svg_errors = svg_conform_by_requirement[requirement] || []
              svgcheck_errors = svgcheck_by_requirement[requirement] || []

              # Display requirement header
              requirement_name = format_requirement_name(requirement)
              puts "\n  #{Paint["🔍 #{requirement_name}:", :cyan, :bold]}"

              # Display SvgConform errors
              if svg_errors.any?
                svg_errors.each do |error|
                  puts "    #{Paint['•', :blue]} #{Paint[error.message, :blue]}"
                end
              else
                puts "    #{Paint['• (no errors)', :gray]}"
              end

              # Display mapped svgcheck errors
              if svgcheck_errors.any?
                svgcheck_errors.each do |error|
                  puts "    #{Paint['↳ [svgcheck]',
                                    :magenta]} #{Paint[error.message,
                                                       :magenta]}"
                end
              else
                puts "    #{Paint['↳ [svgcheck] (no errors)', :gray]}"
              end
            end
          else
            puts "\n#{Paint['🎉 ✓ NO ERRORS IN EITHER SYSTEM! 🎉', :green,
                            :bold]}"
          end

          # Display unmapped svgcheck errors in RED
          if unmapped_svgcheck_errors.any?
            puts "\n#{Paint['🚨 UNMAPPED SVGCHECK ERRORS:', :red, :bold]}"
            puts Paint["These svgcheck errors do not correspond to any SvgConform requirement:",
                       :red]
            unmapped_svgcheck_errors.each do |error|
              puts "    #{Paint['⚠️ [svgcheck]', :red,
                                :bold]} #{Paint[error.message, :red]}"
            end
          end
        rescue StandardError
          # Fallback to the old display if we can't load detailed reports
          if result[:extra_errors]&.any?
            puts "\n#{Paint['⚠️  EXTRA ERRORS IN SVGCONFORM:', :yellow, :bold]}"
            result[:extra_errors].each do |error|
              puts "  • #{error}"
            end
          end

          if result[:missing_errors]&.any?
            puts "\n#{Paint['❌ MISSING ERRORS IN SVGCONFORM:', :red, :bold]}"
            result[:missing_errors].each do |error|
              puts "  • #{error}"
            end
          end

          return unless result[:extra_errors]&.empty? && result[:missing_errors]&.empty?

          puts "\n#{Paint['🎉 ✓ ERROR MESSAGES MATCH PERFECTLY! 🎉', :green,
                          :bold]}"
        end
      end

      # Display overall summary of batch comparison results
      #
      # @param results [Array<Hash>] array of comparison results
      def display_overall_summary(results)
        puts "\n#{Paint['=' * 100, :cyan]}"
        puts Paint["📈 OVERALL COMPATIBILITY SUMMARY", :yellow, :bold]
        puts Paint["=" * 100, :cyan]

        headers = ["File", "SvgConform Errors", "svgcheck Errors", "Match?"]
        rows = []

        results.each do |result|
          status = result[:match] ? "✓" : "✗"
          rows << [
            result[:filename],
            result[:svg_conform_errors],
            result[:svgcheck_errors],
            status,
          ]
        end

        # Add totals
        total_files = results.length
        matching_files = results.count { |r| r[:match] }
        match_percentage = total_files.positive? ? (matching_files.to_f / total_files * 100).round(1) : 0

        rows << ["---", "---", "---", "---"]
        rows << ["TOTAL", "#{total_files} files", "#{matching_files} matches",
                 "#{match_percentage}%"]

        render_gh_style_table(headers, rows)

        puts "\n#{Paint['📊 COMPATIBILITY METRICS:', :blue, :bold]}"
        puts "  🗂️  Total files processed: #{Paint[total_files.to_s, :cyan,
                                                  :bold]}"
        puts "  ✅ Files with matching error counts: #{Paint[matching_files.to_s,
                                                             :green, :bold]}"

        # Color-code the percentage based on value
        percentage_color = if match_percentage >= 90
                             :green
                           elsif match_percentage >= 70
                             :yellow
                           else
                             :red
                           end
        puts "  📈 Compatibility percentage: #{Paint["#{match_percentage}%",
                                                     percentage_color, :bold]}"
      end

      private

      # Render table using table_tennis with proper formatting and color scale
      #
      # @param headers [Array<String>] table headers
      # @param rows [Array<Array>] table rows
      def render_gh_style_table(headers, rows)
        # Convert to hash format that TableTennis expects
        table_data = []

        rows.each do |row|
          row_hash = {}
          headers.each_with_index do |header, index|
            row_hash[header.to_sym] = row[index]
          end
          table_data << row_hash
        end

        # Determine color scale options based on table content
        color_scale_options = determine_color_scale_options(headers, rows)

        # Create TableTennis table with options
        options = {
          color: true,
          separators: true,
          **color_scale_options,
        }

        puts TableTennis.new(table_data, options)
      end

      # Determine appropriate color scale options for TableTennis
      #
      # @param headers [Array<String>] table headers
      # @param _rows [Array<Array>] table rows (unused but kept for interface consistency)
      # @return [Hash] color scale options
      def determine_color_scale_options(headers, _rows)
        # Analyze the table content to determine the best color scale
        if headers.include?("Match?") || headers.include?("Status")
          # For status tables, use mark to highlight matches/mismatches
          {
            mark: lambda { |row|
              status_col = headers.index("Match?") || headers.index("Status")
              return false unless status_col

              status_value = row[status_col].to_s
              status_value.include?("✓") || status_value.include?("MATCH")
            },
            zebra: true,
          }
        elsif headers.any? { |h| h.include?("Count") || h.include?("Errors") }
          # For numeric tables, use color scales on count columns
          count_columns = headers.each_with_index.select do |h, _i|
            h.include?("Count") || h.include?("Errors")
          end.map(&:last)
          if count_columns.any?
            # Use the first count column for color scaling
            column_name = headers[count_columns.first].downcase.gsub(/\s+/,
                                                                     "_").to_sym
            {
              color_scales: column_name,
              zebra: true,
            }
          else
            { zebra: true }
          end
        else
          # Default options
          { zebra: true }
        end
      end

      # Apply color scale to individual cells
      #
      # @param cell [Object] cell value
      # @param col_index [Integer] column index
      # @param _row_index [Integer] row index (unused)
      # @param color_scale [Hash] color scale configuration
      def apply_color_scale(cell, col_index, _row_index, color_scale)
        cell_str = cell.to_s

        case color_scale[:type]
        when :status
          apply_status_color_scale(cell_str)
        when :numeric
          apply_numeric_color_scale(cell_str, col_index)
        else
          apply_default_color_scale(cell_str)
        end
      end

      # Apply status-based color scale
      #
      # @param cell_str [String] cell value as string
      # @return [String] colorized string
      def apply_status_color_scale(cell_str)
        if cell_str.include?("✓") || cell_str.include?("MATCH")
          Paint[cell_str, :green]
        elsif cell_str.include?("✗") || cell_str.include?("MISMATCH")
          Paint[cell_str, :red]
        elsif cell_str.include?("⚠") || cell_str.include?("EXTRA") || cell_str.include?("MISSING")
          Paint[cell_str, :yellow]
        elsif cell_str.include?("BOTH NONE")
          Paint[cell_str, :cyan]
        else
          cell_str
        end
      end

      # Apply numeric-based color scale
      #
      # @param cell_str [String] cell value as string
      # @param _col_index [Integer] column index (unused)
      # @return [String] colorized string
      def apply_numeric_color_scale(cell_str, _col_index)
        # Only apply to numeric columns
        return cell_str unless cell_str.match?(/^\d+$/)

        value = cell_str.to_i

        if value.zero?
          Paint[cell_str, :cyan]
        elsif value <= 5
          Paint[cell_str, :green]
        elsif value <= 20
          Paint[cell_str, :yellow]
        else
          Paint[cell_str, :red]
        end
      end

      # Apply default color scale
      #
      # @param cell_str [String] cell value as string
      # @return [String] colorized string
      def apply_default_color_scale(cell_str)
        # Basic highlighting for common patterns
        if cell_str.include?("true") || cell_str.include?("false")
          if cell_str.include?("true")
            Paint[cell_str,
                  :green]
          else
            Paint[cell_str, :red]
          end
        elsif cell_str.match?(/^\d+%$/) # Percentage
          percentage = cell_str.to_f
          if percentage >= 90
            Paint[cell_str, :green]
          elsif percentage >= 70
            Paint[cell_str, :yellow]
          else
            Paint[cell_str, :red]
          end
        else
          cell_str
        end
      end

      # Determine coverage status based on semantic mapping
      #
      # @param semantic_mapping [Hash] semantic error type mapping
      # @return [String] coverage status string with emoji
      def determine_coverage_status(semantic_mapping)
        return "🤷 NO DATA" unless semantic_mapping&.any?

        svg_conform_errors = semantic_mapping.values.sum do |counts|
          counts[:svg_conform]
        end
        svgcheck_errors = semantic_mapping.values.sum do |counts|
          counts[:svgcheck]
        end

        # Check if SvgConform covers all svgcheck errors
        all_svgcheck_covered = semantic_mapping.all? do |_error_type, counts|
          svg_count = counts[:svg_conform]
          svgcheck_count = counts[:svgcheck]

          # SvgConform covers this error type if it has at least as many errors as svgcheck
          svg_count >= svgcheck_count
        end

        # Check if it's a perfect match (100% both ways)
        perfect_match = semantic_mapping.all? do |_error_type, counts|
          counts[:svg_conform] == counts[:svgcheck]
        end

        if perfect_match && svg_conform_errors.positive? && svgcheck_errors.positive?
          "🎯 FULL MATCH"
        elsif all_svgcheck_covered && svgcheck_errors.positive?
          "✅ COVERED"
        else
          "⚠️ MISMATCH"
        end
      end

      # Format requirement name for display
      #
      # @param requirement_id [String] requirement identifier
      # @return [String] formatted requirement name
      def format_requirement_name(requirement_id)
        case requirement_id
        when "color_restrictions"
          "color_restrictions requirement"
        when "viewbox_required"
          "viewbox_required requirement"
        when "viewbox"
          "viewbox requirement"
        when "namespace"
          "namespace requirement"
        when "namespace_validation"
          "namespace_validation requirement"
        when "allowed_elements"
          "allowed_elements requirement"
        when "font_family"
          "font_family requirement"
        when "no_external_css"
          "no_external_css requirement"
        when "namespace_attributes"
          "namespace_attributes requirement"
        when "style_promotion"
          "style_promotion requirement"
        when "invalid_id_references"
          "invalid_id_references requirement"
        when "forbidden_content"
          "forbidden_content requirement"
        when "property_value"
          "property_value requirement"
        when "link_validation"
          "link_validation requirement"
        when "id_reference"
          "id_reference requirement"
        when "style_syntax"
          "style_syntax requirement"
        when "style_validation"
          "style_validation requirement"
        when "datatype_validation"
          "datatype_validation requirement"
        when "required_attribute"
          "required_attribute requirement"
        when "unmapped"
          "🚨 UNMAPPED SVGCHECK ERROR"
        else
          "🚨 UNKNOWN REQUIREMENT: #{requirement_id}"
        end
      end

      # Generate match status indicator
      #
      # @param value1 [Object] first value to compare
      # @param value2 [Object] second value to compare
      # @return [String] "✓" if values match, "✗" otherwise
      def match_status(value1, value2)
        value1 == value2 ? "✓" : "✗"
      end

      # Group errors by requirement ID
      #
      # @param errors [Array<Issue>] array of error issues
      # @return [Hash] errors grouped by requirement ID
      def group_errors_by_requirement(errors)
        # Check if these are svgcheck errors that need remapping
        engine = SvgConform::ExternalCheckers::Svgcheck::CompatibilityEngine.new

        grouped = {}
        errors.each do |error|
          # For svgcheck errors, try to remap using the compatibility engine
          requirement_id = if error.respond_to?(:requirement_id)
                             # Try to remap using the compatibility engine for all svgcheck errors
                             mapped_req = engine.map_requirement_for_svgcheck(error)
                             mapped_req || error.requirement_id
                           else
                             error.requirement_id
                           end

          grouped[requirement_id] ||= []
          grouped[requirement_id] << error
        end

        grouped
      end

      # Identify svgcheck errors that don't map to any SvgConform requirement
      #
      # @param svgcheck_report [ConformanceReport] svgcheck validation report
      # @param _svg_conform_report [ConformanceReport] SvgConform validation report (unused)
      # @return [Array<Issue>] array of unmapped svgcheck errors
      def identify_unmapped_svgcheck_errors(svgcheck_report,
_svg_conform_report)
        unmapped_errors = []

        # Find svgcheck errors that are marked as "unmapped" by the parser
        svgcheck_report.errors.issues.each do |svgcheck_error|
          # Check if this error was categorized as "unmapped" by the parser
          unmapped_errors << svgcheck_error if svgcheck_error.requirement_id == "unmapped"
        end

        unmapped_errors
      end
    end
  end
end
