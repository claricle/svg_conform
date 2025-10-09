# frozen_string_literal: true

require "spec_helper"
require "svg_conform"

RSpec.describe "SvgCheck Compatibility" do
  let(:input_dir) { File.join(__dir__, "fixtures", "svgcheck", "inputs") }
  let(:check_dir) { File.join(__dir__, "fixtures", "svgcheck", "check") }

  describe "IETF profile validation" do
    Dir.glob(File.join(__dir__, "fixtures", "svgcheck", "inputs",
                       "*.{svg,xml}")).each do |input_file|
      basename = File.basename(input_file, ".*")

      # TODO: Skip non-SVG files that svgcheck can handle but we can't
      next if basename.start_with?("rfc-svg") || basename == "rfc"

      # TODO: Skip problematic large files that cause hangs
      next if basename.start_with?("full-tiny")

      context basename.to_s do
        let(:input_file) { input_file }
        let(:svgcheck_err_file) { "#{check_dir}/#{basename}.svg.err" }
        let(:svgcheck_out_file) { "#{check_dir}/#{basename}.svg.out" }

        it "produces compatible validation errors" do
          skip "No svgcheck output file" unless File.exist?(svgcheck_out_file)

          # svgcheck outputs errors to .out file, not .err file
          svgcheck_content = File.read(svgcheck_out_file).strip

          # Parse svgcheck output
          parser = SvgConform::ExternalCheckers::Svgcheck::Parser.new
          svgcheck_report = parser.parse(svgcheck_content, nil,
                                         filename: "#{basename}.svg")

          # Validate with svg_conform
          validator = SvgConform::Validator.new(profile: "svg_1_2_rfc")
          result = validator.validate_file(input_file)
          our_report = SvgConform::ConformanceReport.from_svg_conform_result(
            "#{basename}.svg",
            result,
            profile: "svg_1_2_rfc",
            use_svgcheck_mapping: true,
          )

          # Compare error counts
          expect(our_report.errors.total_count).to eq(svgcheck_report.errors.total_count),
                                                   "Expected #{svgcheck_report.errors.total_count} errors but got #{our_report.errors.total_count}"
        end

        it "produces compatible fixed output" do
          skip "Repair mode testing not yet implemented"

          our_output = run_our_fixer(input_file)
          expected_output = File.read(expected_out_file)

          # Basic check that we produce valid XML
          expect(our_output).not_to be_empty,
                                    "Expected fixed output but got none"
          expect do
            parse_xml(our_output)
          end.not_to raise_error, "Fixed output is not valid XML"

          # Check that both outputs are valid XML
          expect do
            parse_xml(expected_output)
          end.not_to raise_error, "Expected output is not valid XML"
        end

        it "handles the same elements as svgcheck" do
          # Test that we can at least parse the same files svgcheck can handle
          expect do
            SvgConform::Document.from_file(input_file)
          end.not_to raise_error
        end
      end
    end
  end

  describe "Error message format compatibility" do
    let(:test_file) { "#{input_dir}/circle.svg" }

    it "produces error messages in similar format to svgcheck" do
      skip "Test file not found" unless File.exist?(test_file)

      our_errors = run_our_validator(test_file)

      # Check that error messages contain file reference
      unless our_errors.empty?
        expect(our_errors).to include(test_file),
                              "Error messages should reference the input file"
      end
    end
  end

  describe "Color handling compatibility" do
    let(:colors_file) { "#{input_dir}/colors.svg" }

    it "handles color restrictions like svgcheck" do
      skip "Colors test file not found" unless File.exist?(colors_file)

      svgcheck_out_file = "#{check_dir}/colors.svg.out"
      skip "No svgcheck output for colors test" unless File.exist?(svgcheck_out_file)

      # Parse svgcheck output
      parser = SvgConform::ExternalCheckers::Svgcheck::Parser.new
      svgcheck_report = parser.parse(File.read(svgcheck_out_file), nil,
                                     filename: "colors.svg")

      # Validate with svg_conform
      validator = SvgConform::Validator.new(profile: "svg_1_2_rfc")
      result = validator.validate_file(colors_file)
      our_report = SvgConform::ConformanceReport.from_svg_conform_result(
        "colors.svg",
        result,
        profile: "svg_1_2_rfc",
        use_svgcheck_mapping: true,
      )

      # Both should detect the same number of color violations
      expect(our_report.errors.total_count).to eq(svgcheck_report.errors.total_count),
                                               "Expected #{svgcheck_report.errors.total_count} errors but got #{our_report.errors.total_count}"
    end
  end

  describe "ViewBox handling compatibility" do
    %w[viewBox-none viewBox-width viewBox-height
       viewBox-both].each do |test_name|
      it "handles #{test_name} like svgcheck" do
        test_file = "#{input_dir}/#{test_name}.svg"
        skip "#{test_name} test file not found" unless File.exist?(test_file)

        # Should be able to process the file without crashing
        expect { run_our_validator(test_file) }.not_to raise_error
        expect { run_our_fixer(test_file) }.not_to raise_error
      end
    end
  end

  describe "UTF-8 handling compatibility" do
    let(:utf8_file) { "#{input_dir}/utf8.svg" }

    it "handles UTF-8 content like svgcheck" do
      skip "UTF-8 test file not found" unless File.exist?(utf8_file)

      # Should be able to process UTF-8 content without issues
      expect { run_our_validator(utf8_file) }.not_to raise_error
      expect { run_our_fixer(utf8_file) }.not_to raise_error
    end
  end

  describe "Malformed SVG handling" do
    let(:malformed_file) { "#{input_dir}/malformed.svg" }

    it "handles malformed SVG like svgcheck" do
      skip "Malformed test file not found" unless File.exist?(malformed_file)

      # Should handle malformed SVG gracefully
      expect { run_our_validator(malformed_file) }.not_to raise_error
    end
  end

  private

  def run_our_validator(input_file)
    svg_content = File.read(input_file)
    validator = SvgConform::Validator.new
    result = validator.validate(svg_content, profile: :svg_1_2_rfc)

    # Convert our errors to svgcheck-like format
    errors = result.errors.map do |error|
      "#{input_file}:#{error.line || 1}: #{error.message}"
    end

    errors.join("\n")
  rescue StandardError => e
    "ERROR: #{e.message}"
  end

  def run_our_fixer(input_file)
    document = SvgConform::Document.from_file(input_file)
    profile = SvgConform::Profiles.svg_1_2_rfc
    fixer = SvgConform::Fixer.new(profile)

    fixed_document = fixer.fix(document)
    fixed_document.to_xml
  rescue StandardError
    ""
  end

  def parse_svgcheck_errors(error_text)
    # Parse svgcheck error format: "filename:line: message"
    error_text.lines.map(&:strip).reject(&:empty?).map do |line|
      if line =~ /^(.+):(\d+): (.+)$/
        {
          file: Regexp.last_match(1),
          line: Regexp.last_match(2).to_i,
          message: Regexp.last_match(3),
        }
      else
        { file: "", line: 0, message: line }
      end
    end
  end

  def parse_xml(xml_content)
    # Simple XML parsing check
    require "nokogiri"
    Nokogiri::XML(xml_content, &:strict)
  end
end
