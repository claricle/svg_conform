# frozen_string_literal: true

require "paint"
require "table_tennis"

module SvgConform
  module Commands
    # Check command for validating SVG files
    class Check
      def initialize(file, options)
        @file = file
        @options = options
        # Paint doesn't need initialization like Pastel
      end

      def execute
        unless File.exist?(@file)
          puts Paint["Error: File '#{@file}' not found", :red]
          exit 1
        end

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
          exit 1
        end
      end

      private

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
        output = JSON.pretty_generate(report.to_h)
        write_output(output)
      end

      def write_output(content)
        if @options[:output]
          File.write(@options[:output], content)
          puts Paint["Report written to #{@options[:output]}", :green]
        else
          puts content
        end
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
