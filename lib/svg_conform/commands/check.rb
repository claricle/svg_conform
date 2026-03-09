# frozen_string_literal: true

require "paint"
require "table_tennis"
require "fileutils"
require_relative "../batch_report"

module SvgConform
  module Commands
    # Check command for validating SVG files (single or batch)
    class Check
      def initialize(files, options)
        @files = Array(files)
        @options = options
      end

      def execute
        # Determine which files to process
        files_to_process = determine_files

        if files_to_process.empty?
          puts Paint["Error: No SVG files found", :red]
          abort
        end

        # Single file mode vs batch mode
        if files_to_process.length == 1 && !@options[:directory]
          process_single_file(files_to_process.first)
        else
          process_batch(files_to_process)
        end
      end

      private

      def determine_files
        if @options[:directory]
          # Directory mode: recursive scan
          dir = @options[:directory]
          unless Dir.exist?(dir)
            puts Paint["Error: Directory '#{dir}' not found", :red]
            abort
          end
          Dir.glob(File.join(dir, "**/*.svg")).sort
        elsif @files.empty?
          puts Paint["Error: No files or directory specified", :red]
          abort
          []
        else
          # File mode: validate each file exists
          @files.each do |file|
            unless File.exist?(file)
              puts Paint["Error: File '#{file}' not found", :red]
              abort
            end
          end
          @files
        end
      end

      def process_single_file(file)
        @file = file

        begin
          # Validate the file
          validator = SvgConform::Validator.new
          result = validator.validate_file(@file,
                                           profile: @options[:profile].to_sym)

          # Generate report
          report = SvgConform::ConformanceReport.from_svg_conform_result(
            File.basename(@file),
            result,
            profile: @options[:profile].to_sym,
          )

          # Output based on format
          case @options[:format]
          when "yaml"
            output_yaml(report)
          when "json"
            output_json(report)
          else
            output_table(report)
          end

          # Create remediated file if requested
          create_remediated_file(result) if @options[:fix]

          # Exit with appropriate code
          exit(report.valid? ? 0 : 1)
        rescue StandardError => e
          puts Paint["Error: #{e.message}", :red]
          abort
        end
      end

      def output_table(report)
        puts Paint["SVG Validation Report", :bold]
        puts "=" * 50
        puts "File: #{@file}"
        puts "Profile: #{@options[:profile]}"
        puts "Valid: #{report.valid? ? Paint['✓', :green] : Paint['✗', :red]}"
        puts "Total Errors: #{report.errors.total_count}"
        puts

        if report.errors.total_count.positive?
          puts Paint["Validation Errors:", :bold]
          puts

          # Group errors by type
          error_groups = report.errors.issues.group_by(&:message)

          error_groups.each do |message, errors|
            puts Paint["• #{message}", :red]
            if errors.size > 1
              puts Paint["  (#{errors.size} occurrences)",
                         :black]
            end

            # Show first few locations
            errors.first(3).each do |error|
              puts Paint["    at #{error.element}", :black] if error.element
            end

            if errors.size > 3
              puts Paint["    ... and #{errors.size - 3} more",
                         :black]
            end
            puts
          end
        else
          puts Paint["✓ No validation errors found", :green]
        end
      end

      def output_yaml(report)
        output = report.to_yaml
        write_output(output)
      end

      def output_json(report)
        write_output(report.to_json)
      end

      def write_output(content)
        if @options[:output]
          File.write(@options[:output], content)
          puts Paint["Report written to #{@options[:output]}", :green]
        else
          puts content
        end
      end

      def process_batch(files)
        puts Paint["Batch Processing", :bold]
        puts "=" * 80
        puts "Files: #{files.length}"
        puts "Profile: #{@options[:profile]}"
        puts "=" * 80
        puts

        # Initialize batch report
        batch_report = BatchReport.new
        batch_report.directory = @options[:directory] || File.dirname(files.first)
        batch_report.profile = @options[:profile]

        # Validate output directory if fixing
        if @options[:fix]
          validate_output_options(files)
          prepare_output_directory
        end

        # Process each file
        files.each_with_index do |file, index|
          unless @options[:quiet]
            puts "[#{index + 1}/#{files.length}] #{File.basename(file)}"
          end

          file_result = process_file_for_batch(file)
          batch_report.files << file_result

          # Update manifest if remediated
          if file_result.remediated_path
            batch_report.manifest[file] = file_result.remediated_path
          end
        end

        # Calculate statistics
        batch_report.calculate_statistics

        # Output results
        output_batch_results(batch_report)

        # Create manifest file if requested or if fixing
        create_manifest_file(batch_report) if @options[:manifest] || @options[:fix]

        # Exit with appropriate code
        exit(batch_report.failed.zero? ? 0 : 1)
      end

      def process_file_for_batch(file)
        file_result = FileResult.new
        file_result.filename = File.basename(file)
        file_result.original_path = file

        begin
          # Initial validation
          validator = SvgConform::Validator.new
          initial_result = validator.validate_file(file,
                                                   profile: @options[:profile].to_sym)

          file_result.valid_before = initial_result.valid?
          file_result.errors_before = initial_result.errors.count

          unless @options[:quiet]
            if initial_result.valid?
              puts "  ✓ Already valid"
            else
              puts "  ✗ Invalid: #{initial_result.errors.count} errors"
            end
          end

          # Handle remediation if requested
          if @options[:fix] && !initial_result.valid?
            profile = SvgConform::Profiles.get(@options[:profile].to_sym)
            runner = SvgConform::RemediationRunner.new(profile: profile)
            remediation_result = runner.run_remediation_file(file)

            if remediation_result.remediated_content
              output_path = determine_output_path(file)
              File.write(output_path, remediation_result.remediated_content)

              file_result.valid_after = remediation_result.final_validation.valid?
              file_result.errors_after = remediation_result.final_validation.errors.count
              file_result.remediated_path = output_path
              file_result.status = file_result.valid_after ? "remediated" : "failed"

              unless @options[:quiet]
                if file_result.valid_after
                  puts "  ✓ Remediated successfully"
                else
                  puts "  ⚠ #{file_result.errors_after} errors remain"
                end
              end
            else
              file_result.valid_after = false
              file_result.errors_after = initial_result.errors.count
              file_result.status = "failed"
              unless @options[:quiet]
                puts "  ✗ Remediation failed"
              end
            end
          else
            # No remediation requested or already valid
            file_result.valid_after = file_result.valid_before
            file_result.errors_after = file_result.errors_before
            file_result.status = file_result.valid_before ? "valid" : "failed"
          end
        rescue StandardError => e
          file_result.status = "error"
          file_result.error_message = e.message
          file_result.valid_after = false
          file_result.errors_after = -1
          unless @options[:quiet]
            puts "  ✗ Error: #{e.message}"
          end
        end

        file_result
      end

      def validate_output_options(files)
        return if @options[:in_place]

        # Multiple files require output-dir
        if files.length > 1 && !@options[:output_dir]
          puts Paint["Error: --output-dir required for multiple files with --fix",
                     :red]
          abort
        end

        # In-place requires force
        if @options[:in_place] && !@options[:force]
          puts Paint["Error: --in-place requires --force flag for safety", :red]
          abort
        end
      end

      def prepare_output_directory
        return if @options[:in_place]

        output_dir = @options[:output_dir]
        if output_dir
          FileUtils.mkdir_p(output_dir)
        end
      end

      def determine_output_path(file)
        if @options[:in_place]
          file
        elsif @options[:output_dir]
          File.join(@options[:output_dir], File.basename(file))
        else
          "#{file}.fixed.svg"
        end
      end

      def output_batch_results(batch_report)
        puts
        puts "=" * 80
        puts Paint["BATCH VALIDATION SUMMARY", :bold]
        puts "=" * 80
        puts "Directory: #{batch_report.directory}"
        puts "Profile: #{batch_report.profile}"
        puts "Files processed: #{batch_report.total_files}"
        puts "Valid before: #{batch_report.valid_before}"
        if @options[:fix]
          puts "Remediated: #{batch_report.remediated}"
        end
        puts "Valid after: #{batch_report.valid_after}"
        puts "Failed: #{batch_report.failed}"
        puts "Success rate: #{batch_report.success_rate}%"
        puts "=" * 80

        # Output detailed report if requested
        if @options[:report_format] && @options[:report_output]
          case @options[:report_format]
          when "json"
            File.write(@options[:report_output], batch_report.to_json)
            puts Paint["Detailed JSON report written to #{@options[:report_output]}",
                       :green]
          when "yaml"
            File.write(@options[:report_output], batch_report.to_yaml)
            puts Paint["Detailed YAML report written to #{@options[:report_output]}",
                       :green]
          end
        end
      end

      def create_manifest_file(batch_report)
        return if batch_report.manifest.empty?

        manifest_path = @options[:manifest] || "manifest.json"
        manifest_data = {
          timestamp: batch_report.timestamp,
          profile: batch_report.profile,
          mappings: batch_report.manifest,
        }

        File.write(manifest_path, JSON.pretty_generate(manifest_data))
        puts Paint["Manifest written to #{manifest_path}", :green]
      end

      def create_remediated_file(_result)
        # Load the profile for remediation
        profile = SvgConform::Profiles.get(@options[:profile].to_sym)

        # Create remediation runner
        runner = SvgConform::RemediationRunner.new(profile: profile)

        # Run remediation
        remediation_result = runner.run_remediation_file(@file)

        if remediation_result.success? && remediation_result.remediated_content
          output_file = @options[:fix_output] || "#{@file}.fixed.svg"
          File.write(output_file, remediation_result.remediated_content)
          puts Paint["Remediated file written to #{output_file}", :green]

          # Show remediation summary
          if remediation_result.issues_fixed.positive?
            puts Paint["✓ Fixed #{remediation_result.issues_fixed} issue(s)",
                       :green]
          else
            puts Paint["No issues were fixed (file may already be valid)",
                       :yellow]
          end
        else
          puts Paint["Warning: Could not create remediated file", :yellow]
          if remediation_result.error?
            puts Paint["Error: #{remediation_result.error.message}",
                       :red]
          end
        end
      rescue StandardError => e
        puts Paint["Error creating remediated file: #{e.message}", :red]
      end
    end
  end
end
