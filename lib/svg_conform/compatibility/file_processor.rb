# frozen_string_literal: true

require_relative '../external_checkers/svgcheck'

module SvgConform
  module Compatibility
    # Handles file system operations and validation for compatibility analysis
    class FileProcessor
      def initialize(context)
        @context = context
      end

      def validate_environment
        if @context.single_file_analysis?
          validate_single_file
        else
          validate_batch_environment
        end
      end

      def discover_files
        return [@context.file] if @context.single_file_analysis?

        discover_batch_files
      end

      def parse_svgcheck_outputs(filename)
        # Use the new external checker report generator
        report_generator = SvgConform::ExternalCheckers::Svgcheck::ReportGenerator.new

        output_file = File.join(@context.outputs_dir, "#{filename}.out")
        error_file = File.join(@context.outputs_dir, "#{filename}.err")
        code_file = File.join(@context.outputs_dir, "#{filename}.code")

        report_generator.generate_from_files(filename,
          output_file: output_file,
          error_file: error_file,
          code_file: code_file)
      end

      def file_exists?(filename)
        File.exist?(File.join(@context.inputs_dir, filename))
      end

      def input_file_path(filename)
        File.join(@context.inputs_dir, filename)
      end

      def xml_file?(filename)
        filename.end_with?('.xml')
      end

      def svg_file?(filename)
        filename.end_with?('.svg')
      end

      def read_file_content(filename)
        File.read(input_file_path(filename))
      end

      def svgcheck_repaired_file_path(filename)
        File.join(@context.outputs_dir, "#{filename}.file")
      end

      def svgcheck_repaired_file_exists?(filename)
        File.exist?(svgcheck_repaired_file_path(filename))
      end

      def read_svgcheck_repaired_content(filename)
        File.read(svgcheck_repaired_file_path(filename))
      end

      private

      def validate_single_file
        input_file = @context.input_file_path

        raise "Input file not found: #{input_file}" unless File.exist?(input_file)

        raise "Svgcheck outputs directory not found: #{@context.outputs_dir}" unless Dir.exist?(@context.outputs_dir)

        true
      end

      def validate_batch_environment
        raise "Inputs directory not found: #{@context.inputs_dir}" unless Dir.exist?(@context.inputs_dir)

        raise "Outputs directory not found: #{@context.outputs_dir}" unless Dir.exist?(@context.outputs_dir)

        true
      end

      def discover_batch_files
        all_files = Dir.glob(File.join(@context.inputs_dir, '*')).map { |f| File.basename(f) }
        svg_files = all_files.select { |f| svg_file?(f) }

        raise "No SVG files found in #{@context.inputs_dir}" if svg_files.empty?

        # Report filtered files for user awareness
        non_svg_files = all_files - svg_files
        puts "ℹ️  Skipping #{non_svg_files.length} non-SVG files: #{non_svg_files.join(', ')}" if non_svg_files.any?

        svg_files
      end
    end
  end
end
