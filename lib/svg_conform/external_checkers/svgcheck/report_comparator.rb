# frozen_string_literal: true

require_relative '../../conformance_report'
require_relative '../../validator'
require_relative '../../profiles'

module SvgConform
  module ExternalCheckers
    module Svgcheck
      # Sophisticated report comparison mechanism for svg_conform vs svgcheck
      class ReportComparator
        attr_reader :test_files_dir, :svgcheck_outputs_dir

        def initialize(test_files_dir: 'svgcheck/svgcheck/Tests', svgcheck_outputs_dir: 'spec/fixtures/svgcheck')
          @test_files_dir = test_files_dir
          @svgcheck_outputs_dir = svgcheck_outputs_dir
        end

        # Compare all test files between svg_conform and svgcheck
        def compare_all_test_files
          test_files = find_test_files

          results = {
            total_files: test_files.length,
            matching: 0,
            different: 0,
            errors: 0,
            differences: {}
          }

          test_files.each do |filename|
            begin
              comparison = compare_file(filename)

              if comparison[:identical]
                results[:matching] += 1
              else
                results[:different] += 1
                results[:differences][filename] = comparison
              end

            rescue => e
              results[:errors] += 1
              results[:differences][filename] = {
                error: e.message,
                summary: "Error during comparison: #{e.message}"
              }
            end
          end

          results
        end

        # Compare a single file between svg_conform and svgcheck
        def compare_file(filename)
          svg_conform_report = generate_svg_conform_report(filename)
          svgcheck_report = load_svgcheck_report(filename)

          return { error: 'No svgcheck report found', identical: false } unless svgcheck_report

          # Perform detailed comparison
          comparison = svg_conform_report.compare_with(svgcheck_report)

          # Add semantic comparison
          semantic_comparison = perform_semantic_comparison(svg_conform_report, svgcheck_report)
          comparison[:semantic] = semantic_comparison

          comparison
        end

        private

        def find_test_files
          return [] unless Dir.exist?(@test_files_dir)

          pattern = File.join(@test_files_dir, '*.{svg,xml}')
          Dir.glob(pattern).map { |path| File.basename(path) }.sort
        end

        def generate_svg_conform_report(filename)
          input_file = File.join(@test_files_dir, filename)
          return nil unless File.exist?(input_file)

          # Load svg_1_2_rfc profile
          profile = SvgConform::Profiles.load_profile(:svg_1_2_rfc)

          # Validate using svg_conform
          validator = SvgConform::Validator.new(profile)
          validation_result = validator.validate_file(input_file)

          # Create report with svgcheck mapping for compatibility
          ConformanceReport.from_svg_conform_result(
            filename,
            validation_result,
            profile: 'svg_1_2_rfc',
            use_svgcheck_mapping: true
          )
        end

        def load_svgcheck_report(filename)
          base_name = File.basename(filename, '.*')
          extension = File.extname(filename)

          # Try to load from check mode first, then repair mode
          check_error_file = File.join(@svgcheck_outputs_dir, 'check', "#{base_name}#{extension}.out")
          repair_error_file = File.join(@svgcheck_outputs_dir, 'repair', "#{base_name}#{extension}.out")

          error_file = if File.exist?(check_error_file)
                         check_error_file
                       elsif File.exist?(repair_error_file)
                         repair_error_file
                       else
                         return nil
                       end

          error_content = File.read(error_file)
          ConformanceReport.from_svgcheck_result(filename, error_content)
        end

        def perform_semantic_comparison(svg_conform_report, svgcheck_report)
          semantic_issues = []

          # Compare semantic equivalence of errors
          svg_conform_errors = group_errors_semantically(svg_conform_report.errors.issues)
          svgcheck_errors = group_errors_semantically(svgcheck_report.errors.issues)

          # Find semantic mismatches
          all_semantic_keys = (svg_conform_errors.keys + svgcheck_errors.keys).uniq

          all_semantic_keys.each do |semantic_key|
            svg_count = svg_conform_errors[semantic_key]&.length || 0
            svgcheck_count = svgcheck_errors[semantic_key]&.length || 0

            next if svg_count == svgcheck_count

            semantic_issues << {
              semantic_key: semantic_key,
              svg_conform_count: svg_count,
              svgcheck_count: svgcheck_count,
              difference: svg_count - svgcheck_count
            }
          end

          {
            total_semantic_groups: all_semantic_keys.length,
            matching_groups: all_semantic_keys.length - semantic_issues.length,
            mismatched_groups: semantic_issues.length,
            issues: semantic_issues
          }
        end

        def group_errors_semantically(errors)
          errors.group_by do |error|
            # Create semantic key based on requirement and core issue
            requirement = error.requirement_id
            attribute = error.attribute
            element = error.element

            if attribute && element
              "#{requirement}:#{element}:#{attribute}"
            elsif element
              "#{requirement}:#{element}"
            else
              requirement
            end
          end
        end
      end
    end
  end
end
