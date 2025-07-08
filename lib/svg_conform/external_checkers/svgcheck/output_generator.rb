# frozen_string_literal: true

require 'open3'
require 'fileutils'

module SvgConform
  module ExternalCheckers
    module Svgcheck
      # Generates svgcheck outputs for comparison testing
      class OutputGenerator
        attr_reader :svgcheck_exec, :svgcheck_path

        def initialize(svgcheck_exec: 'python3', svgcheck_path: 'svgcheck/svgcheck')
          @svgcheck_exec = svgcheck_exec
          @svgcheck_path = svgcheck_path
        end

        # Generate svgcheck outputs for a given input file
        def generate(input_file, mode: :both)
          results = {}

          case mode
          when :check
            results[:check] = generate_mode_output(input_file, :check)
          when :repair
            results[:repair] = generate_mode_output(input_file, :repair)
          when :both
            results[:check] = generate_mode_output(input_file, :check)
            results[:repair] = generate_mode_output(input_file, :repair)
          else
            raise ArgumentError, "Invalid mode: #{mode}. Must be :check, :repair, or :both"
          end

          results
        end

        private

        def generate_mode_output(input_file, mode)
          unless available?
            return {
              success: false,
              error: "svgcheck not available (#{@svgcheck_exec} or #{@svgcheck_path} not found)"
            }
          end

          begin
            # Change to svgcheck directory to run the module
            original_dir = Dir.pwd
            Dir.chdir(@svgcheck_path)

            # Build command based on mode
            relative_input = File.join('Tests', File.basename(input_file))
            cmd = if mode == :repair
                    [@svgcheck_exec, 'run.py', '--repair', relative_input]
                  else
                    [@svgcheck_exec, 'run.py', relative_input] # check mode - no --repair flag
                  end

            stdout, stderr, status = Open3.capture3(*cmd)

            # Return to original directory
            Dir.chdir(original_dir)

            {
              success: true,
              stdout: stdout,
              stderr: stderr,
              exit_code: status.exitstatus,
              mode: mode
            }
          rescue StandardError => e
            # Make sure we return to original directory even on error
            Dir.chdir(original_dir) if Dir.pwd != original_dir

            {
              success: false,
              error: "Error running svgcheck in #{mode} mode: #{e.message}"
            }
          end
        end

        def available?
          command_available?(@svgcheck_exec) && Dir.exist?(@svgcheck_path)
        end

        def command_available?(command)
          system("which #{command} > /dev/null 2>&1") ||
            system("where #{command} > NUL 2>&1") || # Windows
            File.executable?(command) # Direct path
        end
      end
    end
  end
end
