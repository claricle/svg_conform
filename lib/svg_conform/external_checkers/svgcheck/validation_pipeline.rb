# frozen_string_literal: true

require_relative 'output_generator'
require_relative 'report_generator'
require_relative 'report_comparator'
require_relative '../../validator'
require_relative '../../profiles'

module SvgConform
  module ExternalCheckers
    module Svgcheck
      # Pipeline to ensure svg_conform outputs are compatible with svgcheck
      class ValidationPipeline
        attr_reader :test_files_dir, :output_dir

        def initialize(test_files_dir: 'svgcheck/svgcheck/Tests', output_dir: 'spec/fixtures/svgcheck')
          @test_files_dir = test_files_dir
          @output_dir = output_dir
          @generator = OutputGenerator.new
          @report_generator = ReportGenerator.new
          @comparator = ReportComparator.new(test_files_dir: test_files_dir, svgcheck_outputs_dir: output_dir)
        end

        # Run complete validation pipeline
        def run_validation_pipeline(mode: :both)
          results = {
            stage: 'complete_pipeline',
            total_files: 0,
            successful_generations: 0,
            successful_comparisons: 0,
            failed_generations: 0,
            failed_comparisons: 0,
            compatibility_issues: [],
            summary: {}
          }

          test_files = find_test_files
          results[:total_files] = test_files.length

          puts "🚀 Starting validation pipeline for #{test_files.length} files..."

          # Stage 1: Generate svgcheck outputs
          puts "\n📋 Stage 1: Generating svgcheck outputs..."
          generation_results = generate_outputs_for_files(test_files, mode)
          results[:successful_generations] = generation_results[:successful]
          results[:failed_generations] = generation_results[:failed]

          # Stage 2: Compare reports
          puts "\n📋 Stage 2: Comparing svg_conform vs svgcheck reports..."
          comparison_results = compare_all_reports
          results[:successful_comparisons] = comparison_results[:matching]
          results[:failed_comparisons] = comparison_results[:different]
          results[:compatibility_issues] = comparison_results[:differences]

          # Stage 3: Generate summary
          results[:summary] = generate_pipeline_summary(results)

          results
        end

        # Validate output compatibility for a single file
        def validate_file_compatibility(filename)
          result = {
            filename: filename,
            svg_conform_validation: nil,
            svgcheck_outputs: nil,
            comparison: nil,
            compatible: false,
            issues: []
          }

          begin
            # Generate svg_conform validation
            result[:svg_conform_validation] = generate_svg_conform_validation(filename)

            # Generate svgcheck outputs
            result[:svgcheck_outputs] = @generator.generate(filename, mode: :both)

            # Compare outputs
            if result[:svgcheck_outputs].values.all? { |r| r[:success] }
              result[:comparison] = @comparator.compare_file(filename)
              result[:compatible] = result[:comparison][:identical]

              unless result[:compatible]
                result[:issues] = extract_compatibility_issues(result[:comparison])
              end
            else
              result[:issues] << 'Failed to generate svgcheck outputs'
            end

          rescue => e
            result[:issues] << "Error during validation: #{e.message}"
          end

          result
        end

        # Generate comprehensive compatibility report
        def generate_compatibility_report
          pipeline_results = run_validation_pipeline

          report = {
            timestamp: Time.now.iso8601,
            pipeline_version: SvgConform::VERSION,
            total_files: pipeline_results[:total_files],
            compatibility_score: calculate_compatibility_score(pipeline_results),
            results: pipeline_results,
            recommendations: generate_recommendations(pipeline_results)
          }

          report
        end

        private

        def find_test_files
          return [] unless Dir.exist?(@test_files_dir)

          pattern = File.join(@test_files_dir, '*.{svg,xml}')
          Dir.glob(pattern).map { |path| File.basename(path) }.sort
        end

        def generate_outputs_for_files(test_files, mode)
          results = { successful: 0, failed: 0, errors: [] }

          test_files.each do |filename|
            begin
              outputs = @generator.generate(filename, mode: mode)

              if outputs.values.all? { |result| result[:success] }
                results[:successful] += 1
                puts "  ✅ #{filename}"
              else
                results[:failed] += 1
                puts "  ❌ #{filename}"
                results[:errors] << { filename: filename, error: 'Generation failed' }
              end
            rescue => e
              results[:failed] += 1
              puts "  ❌ #{filename}: #{e.message}"
              results[:errors] << { filename: filename, error: e.message }
            end
          end

          results
        end

        def compare_all_reports
          @comparator.compare_all_test_files
        end

        def generate_svg_conform_validation(filename)
          input_file = File.join(@test_files_dir, filename)
          return nil unless File.exist?(input_file)

          profile = SvgConform::Profiles.load_profile(:svg_1_2_rfc)
          validator = SvgConform::Validator.new(profile)
          validator.validate_file(input_file)
        end

        def extract_compatibility_issues(comparison)
          issues = []

          # Add basic comparison issues
          comparison[:differences]&.each do |diff|
            issues << "Report difference: #{diff}"
          end

          # Add semantic comparison issues
          if comparison[:semantic] && comparison[:semantic][:issues].any?
            comparison[:semantic][:issues].each do |semantic_issue|
              issues << "Semantic mismatch: #{semantic_issue[:semantic_key]} " \
                       "(svg_conform: #{semantic_issue[:svg_conform_count]}, " \
                       "svgcheck: #{semantic_issue[:svgcheck_count]})"
            end
          end

          issues
        end

        def calculate_compatibility_score(pipeline_results)
          return 0.0 if pipeline_results[:total_files] == 0

          successful_files = pipeline_results[:successful_comparisons]
          total_files = pipeline_results[:total_files]

          (successful_files.to_f / total_files * 100).round(2)
        end

        def generate_recommendations(pipeline_results)
          recommendations = []

          # Generation issues
          if pipeline_results[:failed_generations] > 0
            recommendations << {
              category: 'generation',
              priority: 'high',
              message: "#{pipeline_results[:failed_generations]} files failed svgcheck output generation. " \
                      "Check svgcheck installation and test file accessibility."
            }
          end

          # Compatibility issues
          if pipeline_results[:failed_comparisons] > 0
            recommendations << {
              category: 'compatibility',
              priority: 'high',
              message: "#{pipeline_results[:failed_comparisons]} files show compatibility issues. " \
                      "Review profile configuration and requirement mappings."
            }
          end

          # Profile issues
          compatibility_score = calculate_compatibility_score(pipeline_results)
          if compatibility_score < 90.0
            recommendations << {
              category: 'profile',
              priority: 'medium',
              message: "Compatibility score is #{compatibility_score}%. " \
                      "Consider reviewing svg_1_2_rfc profile configuration against svgcheck source."
            }
          end

          recommendations
        end

        def generate_pipeline_summary(results)
          {
            compatibility_score: calculate_compatibility_score(results),
            generation_success_rate: calculate_success_rate(results[:successful_generations], results[:total_files]),
            comparison_success_rate: calculate_success_rate(results[:successful_comparisons], results[:total_files]),
            total_issues: results[:compatibility_issues].length
          }
        end

        def calculate_success_rate(successful, total)
          return 0.0 if total == 0
          (successful.to_f / total * 100).round(2)
        end
      end
    end
  end
end
