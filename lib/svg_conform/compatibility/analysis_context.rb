# frozen_string_literal: true

module SvgConform
  module Compatibility
    # Value object representing the context and configuration for compatibility analysis
    class AnalysisContext
      attr_reader :mode, :profile, :semantic, :svgcheck_dir, :file, :output_file

      def initialize(options = {})
        @mode = (options[:mode] || 'check').to_sym
        @profile = options[:profile]&.to_sym || :svg_1_2_rfc_compatible
        @semantic = options[:semantic] || false
        @svgcheck_dir = options[:svgcheck_dir] || 'spec/fixtures/svgcheck'
        @file = options[:file]
        @output_file = options[:output]
      end

      def single_file_analysis?
        !@file.nil?
      end

      def batch_analysis?
        @file.nil?
      end

      def check_mode?
        @mode == :check
      end

      def repair_mode?
        @mode == :repair
      end

      def semantic_analysis?
        @semantic
      end

      def file_output?
        !@output_file.nil?
      end

      def inputs_dir
        File.join(@svgcheck_dir, 'inputs')
      end

      def outputs_dir
        File.join(@svgcheck_dir, @mode.to_s)
      end

      def input_file_path
        return nil unless single_file_analysis?

        File.join(inputs_dir, @file)
      end

      def to_h
        {
          mode: @mode,
          profile: @profile,
          semantic: @semantic,
          svgcheck_dir: @svgcheck_dir,
          file: @file,
          output_file: @output_file
        }
      end
    end
  end
end
