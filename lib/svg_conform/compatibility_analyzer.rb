# frozen_string_literal: true

require "json"

module SvgConform
  # Analyzes compatibility between svg_conform and svgcheck results
  class CompatibilityAnalyzer
    attr_reader :results

    def initialize
      @results = {}
    end

    # Analyze all test files and compare results
    def analyze_all_files
      input_dir = File.join(__dir__, "..", "..", "spec", "fixtures",
                            "svgcheck", "inputs")
      check_dir = File.join(__dir__, "..", "..", "spec", "fixtures",
                            "svgcheck", "check")
      repair_dir = File.join(__dir__, "..", "..", "spec", "fixtures",
                             "svgcheck", "repair")

      Dir.glob(File.join(input_dir, "*.svg")).each do |input_file|
        basename = File.basename(input_file, ".svg")
        next if basename.start_with?("rfc") # Skip non-SVG files

        puts "Analyzing #{basename}..."
        result = analyze_file(input_file, check_dir, repair_dir)
        @results[basename] = result
      end

      @results
    end

    # Analyze a single file
    def analyze_file(input_file, check_dir, repair_dir)
      basename = File.basename(input_file, ".svg")

      # Load svgcheck results
      svgcheck_out = load_svgcheck_file(check_dir, "#{basename}.svg.out")
      svgcheck_err = load_svgcheck_file(check_dir, "#{basename}.svg.err")
      svgcheck_code = load_svgcheck_file(check_dir, "#{basename}.svg.code")
      svgcheck_repair = load_svgcheck_file(repair_dir, "#{basename}.svg.file")

      # Run our validation
      our_validation = run_our_validation(input_file)
      our_remediation = nil # Skip remediation for now

      # Parse svgcheck results
      svgcheck_errors = parse_svgcheck_errors(svgcheck_out)
      svgcheck_valid = svgcheck_out.include?("INFO: File conforms to SVG requirements")

      # Compare results
      {
        file: basename,
        input_file: input_file,
        svgcheck: {
          valid: svgcheck_valid,
          errors: svgcheck_errors,
          error_count: svgcheck_errors.length,
          exit_code: svgcheck_code&.strip&.to_i,
          raw_output: svgcheck_out,
          raw_error: svgcheck_err,
          repaired_content: svgcheck_repair,
        },
        our_results: {
          valid: our_validation[:valid],
          errors: our_validation[:errors],
          error_count: our_validation[:errors].length,
          remediated_content: our_remediation,
        },
        compatibility: analyze_compatibility(svgcheck_errors, svgcheck_valid,
                                             our_validation),
      }
    end

    # Generate a detailed report
    def generate_report
      return "No analysis results available" if @results.empty?

      report = []
      report << "SVG Conform vs SVGCheck Compatibility Analysis"
      report << ("=" * 50)
      report << ""

      # Summary statistics
      total_files = @results.length
      compatible_files = @results.count do |_, r|
        r[:compatibility][:overall_compatible]
      end

      report << "Summary:"
      report << "  Total files analyzed: #{total_files}"
      report << "  Compatible files: #{compatible_files}"
      report << "  Compatibility rate: #{(compatible_files.to_f / total_files * 100).round(1)}%"
      report << ""

      # Detailed analysis for each file
      @results.each do |basename, result|
        report << "File: #{basename}"
        report << ("-" * 30)

        # Validation comparison
        svgcheck_valid = result[:svgcheck][:valid]
        our_valid = result[:our_results][:valid]

        report << "  Validation:"
        report << "    SVGCheck: #{svgcheck_valid ? 'VALID' : 'INVALID'} (#{result[:svgcheck][:error_count]} errors)"
        report << "    Our tool:  #{our_valid ? 'VALID' : 'INVALID'} (#{result[:our_results][:error_count]} errors)"
        report << "    Match: #{svgcheck_valid == our_valid ? 'YES' : 'NO'}"

        # Error analysis
        if result[:svgcheck][:error_count].positive? || result[:our_results][:error_count].positive?
          report << "  Errors:"

          if result[:svgcheck][:error_count].positive?
            report << "    SVGCheck errors:"
            result[:svgcheck][:errors].each do |error|
              report << "      - Line #{error[:line]}: #{error[:message]}"
            end
          end

          if result[:our_results][:error_count].positive?
            report << "    Our errors:"
            result[:our_results][:errors].each do |error|
              report << "      - #{error}"
            end
          end
        end

        # Compatibility issues
        compatibility = result[:compatibility]
        unless compatibility[:issues].empty?
          report << "  Compatibility Issues:"
          compatibility[:issues].each do |issue|
            report << "    - #{issue}"
          end
        end

        report << ""
      end

      # Pattern analysis
      report << "Common Patterns:"
      report << ("-" * 20)

      # Find common error types
      all_svgcheck_errors = @results.values.flat_map do |r|
        r[:svgcheck][:errors]
      end
      error_patterns = all_svgcheck_errors.group_by do |e|
        extract_error_pattern(e[:message])
      end

      error_patterns.each do |pattern, errors|
        report << "  #{pattern}: #{errors.length} occurrences"
      end

      report.join("\n")
    end

    private

    def load_svgcheck_file(dir, filename)
      file_path = File.join(dir, filename)
      return nil unless File.exist?(file_path)

      File.read(file_path)
    rescue StandardError
      nil
    end

    def run_our_validation(input_file)
      svg_content = File.read(input_file)
      validator = SvgConform::Validator.new
      result = validator.validate(svg_content, profile: :svg_1_2_rfc)

      {
        valid: result.valid?,
        errors: result.errors.map { |e| "Line #{e.line || '?'}: #{e.message}" },
      }
    rescue StandardError => e
      {
        valid: false,
        errors: ["ERROR: #{e.message}"],
      }
    end

    def run_our_remediation(input_file)
      document = SvgConform::Document.from_file(input_file)
      profile = SvgConform::Profiles.get(:svg_1_2_rfc)
      fixer = SvgConform::Fixer.new(profile)

      fixed_document = fixer.fix(document)
      fixed_document.to_xml
    rescue StandardError => e
      "ERROR: #{e.message}"
    end

    def parse_svgcheck_errors(output)
      return [] if output.nil? || output.empty?

      errors = []
      output.lines.each do |line|
        line = line.strip
        next if line.empty?
        next if line.start_with?("INFO:")
        next if line.include?("File conforms to SVG requirements")

        # Parse error format: "filename:line: message"
        if line =~ /^(.+):(\d+): (.+)$/
          errors << {
            file: Regexp.last_match(1),
            line: Regexp.last_match(2).to_i,
            message: Regexp.last_match(3),
          }
        elsif line.start_with?("ERROR:")
          errors << {
            file: "",
            line: 0,
            message: line,
          }
        end
      end

      errors
    end

    def analyze_compatibility(svgcheck_errors, svgcheck_valid, our_validation)
      issues = []

      # Check if validation results match
      if svgcheck_valid != our_validation[:valid]
        if svgcheck_valid && !our_validation[:valid]
          issues << "We reject a file that svgcheck accepts"
        elsif !svgcheck_valid && our_validation[:valid]
          issues << "We accept a file that svgcheck rejects"
        end
      end

      # Check error count differences
      error_count_diff = (svgcheck_errors.length - our_validation[:errors].length).abs
      issues << "Error count differs by #{error_count_diff}" if error_count_diff.positive?

      # Check for missing error types
      svgcheck_error_types = svgcheck_errors.map do |e|
        extract_error_pattern(e[:message])
      end.uniq
      our_error_types = our_validation[:errors].map do |e|
        extract_error_pattern(e)
      end.uniq

      missing_types = svgcheck_error_types - our_error_types
      extra_types = our_error_types - svgcheck_error_types

      missing_types.each { |type| issues << "Missing error type: #{type}" }
      extra_types.each { |type| issues << "Extra error type: #{type}" }

      {
        overall_compatible: issues.empty?,
        issues: issues,
        error_count_match: svgcheck_errors.length == our_validation[:errors].length,
        validation_result_match: svgcheck_valid == our_validation[:valid],
      }
    end

    def extract_error_pattern(error_message)
      # Extract the general pattern from an error message
      case error_message
      when /attribute '(\w+)' does not allow the value '([^']+)'/
        "invalid_attribute_value:#{Regexp.last_match(1)}"
      when /Color '([^']+)' in attribute '(\w+)'/
        "invalid_color:#{Regexp.last_match(2)}"
      when /viewBox/i
        "viewbox_issue"
      when /namespace/i
        "namespace_issue"
      when /font/i
        "font_issue"
      else
        error_message.split(":").first || error_message
      end
    end
  end
end
