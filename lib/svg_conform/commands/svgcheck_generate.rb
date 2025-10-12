# frozen_string_literal: true

require "English"
require "fileutils"
require "paint"
require "open3"

module SvgConform
  module Commands
    # Generate svgcheck outputs using Open3 for proper process management
    class SvgcheckGenerate
      def initialize(options)
        @options = options
        @svgcheck_exec = @options[:svgcheck_exec] || "svgcheck"
        @fixtures_path = @options[:fixtures_path] || "spec/fixtures/svgcheck"
        @test_dir = "svgcheck/svgcheck/Tests"
        @single_file = @options[:single_file]
        @force = @options[:force] || false
        @verbose = @options[:verbose] || false
        @mode = @options[:mode] || "both" # 'check', 'repair', or 'both'
      end

      def execute
        puts Paint["🔧 Generating svgcheck outputs...", :blue, :bold]
        puts Paint["📋 Mode: #{@mode}", :cyan]

        # Ensure output directories exist
        ensure_output_directories

        if @single_file
          generate_single_output(@single_file)
        else
          generate_all_outputs
        end
      end

      private

      def ensure_output_directories
        case @mode
        when "check"
          FileUtils.mkdir_p(File.join(@fixtures_path, "check"))
        when "repair"
          FileUtils.mkdir_p(File.join(@fixtures_path, "repair"))
        when "both"
          FileUtils.mkdir_p(File.join(@fixtures_path, "check"))
          FileUtils.mkdir_p(File.join(@fixtures_path, "repair"))
        end
      end

      def generate_single_output(filename)
        test_file_path = File.join(@test_dir, filename)

        unless File.exist?(test_file_path)
          puts Paint["❌ Test file not found: #{test_file_path}", :red]
          return false
        end

        success = true

        case @mode
        when "check"
          success = generate_mode_output(filename, "check")
        when "repair"
          success = generate_mode_output(filename, "repair")
        when "both"
          check_success = generate_mode_output(filename, "check")
          repair_success = generate_mode_output(filename, "repair")
          success = check_success && repair_success
        end

        if success
          puts Paint["✅ Generated outputs for #{filename}", :green]
        else
          puts Paint["❌ Failed to generate outputs for #{filename}", :red]
        end

        success
      end

      def generate_mode_output(filename, mode)
        test_file_path = File.join(@test_dir, filename)
        base_name = File.basename(filename, ".*")
        extension = File.extname(filename)

        # Create mode-specific output directory and base path
        mode_dir = File.join(@fixtures_path, mode)
        output_base = File.join(mode_dir, "#{base_name}#{extension}")

        # Check if outputs already exist
        expected_files = if mode == "repair"
                           ["#{output_base}.out", "#{output_base}.err",
                            "#{output_base}.code", "#{output_base}.file"]
                         else
                           ["#{output_base}.out", "#{output_base}.err",
                            "#{output_base}.code"]
                         end

        if expected_files.any? { |f| File.exist?(f) } && !@force
          puts Paint["⚠️  #{mode.capitalize} outputs already exist for #{filename} (use --force to overwrite)",
                     :yellow]
          return true
        end

        puts Paint["📄 Generating #{mode} outputs for #{filename}...", :cyan]

        run_svgcheck_mode(test_file_path, output_base, mode)
      end

      def generate_all_outputs
        test_files = find_test_files

        if test_files.empty?
          puts Paint["❌ No test files found in #{@test_dir}", :red]
          return
        end

        puts Paint["📊 Found #{test_files.length} test files", :cyan]

        success_count = 0
        skip_count = 0
        error_count = 0

        test_files.each do |filename|
          # Skip problematic files
          if should_skip_file?(filename)
            puts Paint["⏭️  Skipping #{filename} (too large or problematic)",
                       :yellow]
            skip_count += 1
            next
          end

          if generate_single_output(filename)
            success_count += 1
          else
            error_count += 1
          end
        end

        puts "\n#{Paint['📈 GENERATION SUMMARY:', :blue, :bold]}"
        puts "  ✅ Successfully generated: #{Paint[success_count.to_s, :green,
                                                   :bold]}"
        puts "  ⏭️  Skipped: #{Paint[skip_count.to_s, :yellow, :bold]}"
        puts "  ❌ Failed: #{Paint[error_count.to_s, :red, :bold]}"
        puts "  📁 Output directory: #{Paint[@fixtures_path, :cyan]}"

        case @mode
        when "check"
          puts "  📂 Check outputs: #{Paint[File.join(@fixtures_path, 'check'),
                                            :cyan]}"
        when "repair"
          puts "  📂 Repair outputs: #{Paint[File.join(@fixtures_path, 'repair'),
                                             :cyan]}"
        when "both"
          puts "  📂 Check outputs: #{Paint[File.join(@fixtures_path, 'check'),
                                            :cyan]}"
          puts "  📂 Repair outputs: #{Paint[File.join(@fixtures_path, 'repair'),
                                             :cyan]}"
        end
      end

      def find_test_files
        return [] unless Dir.exist?(@test_dir)

        # Find all .svg and .xml files
        pattern = File.join(@test_dir, "*.{svg,xml}")
        Dir.glob(pattern).map { |path| File.basename(path) }.sort
      end

      def should_skip_file?(filename)
        # Skip files that are known to be problematic
        skip_patterns = [
          /^full-tiny\.xml$/, # Too large
          /^cache_saved/, # Cache directory
        ]

        skip_patterns.any? { |pattern| filename.match?(pattern) }
      end

      def run_svgcheck_mode(input_file, output_base, mode)
        # Check if python3 is available
        unless command_available?("python3")
          puts Paint["❌ python3 not found. Please install Python 3.", :red]
          return false
        end

        # Check if svgcheck module is available
        svgcheck_dir = "svgcheck/svgcheck"
        unless Dir.exist?(svgcheck_dir)
          puts Paint["❌ svgcheck directory not found: #{svgcheck_dir}", :red]
          return false
        end

        begin
          # Change to svgcheck directory to run the module
          original_dir = Dir.pwd
          Dir.chdir(svgcheck_dir)

          # Build command based on mode
          relative_input = File.join("Tests", File.basename(input_file))
          cmd = if mode == "repair"
                  ["python3", "run.py", "--repair", relative_input]
                else
                  ["python3", "run.py", relative_input] # check mode - no --repair flag
                end

          puts "  Running #{mode}: #{cmd.join(' ')}" if @verbose

          stdout, stderr, status = Open3.capture3(*cmd)

          # Return to original directory
          Dir.chdir(original_dir)

          # svgcheck writes validation messages to stderr, save as .out (following existing convention)
          File.write("#{output_base}.out", stderr)

          # svgcheck writes any other errors to stderr, but we'll keep a separate .err for consistency
          File.write("#{output_base}.err", "")

          # Write exit code to .code file
          File.write("#{output_base}.code", status.exitstatus.to_s)

          # For repair mode, svgcheck writes remediated SVG content to stdout
          # For check mode, stdout should be empty or minimal
          File.write("#{output_base}.file", stdout) if mode == "repair"

          puts "  #{mode.capitalize} exit status: #{status.exitstatus}" if @verbose
          puts "  #{mode.capitalize} stdout lines: #{stdout.lines.count}" if @verbose
          puts "  #{mode.capitalize} stderr lines: #{stderr.lines.count}" if @verbose

          true
        rescue StandardError => e
          puts Paint["❌ Error running svgcheck in #{mode} mode: #{e.message}",
                     :red]
          # Make sure we return to original directory even on error
          Dir.chdir(original_dir) if Dir.pwd != original_dir
          false
        end
      end

      def command_available?(command)
        # Check if command is available in PATH
        system("which #{command} > /dev/null 2>&1") ||
          system("where #{command} > NUL 2>&1") || # Windows
          File.executable?(command) # Direct path
      end
    end
  end
end
