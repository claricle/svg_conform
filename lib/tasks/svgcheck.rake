# frozen_string_literal: true

require_relative '../svg_conform/external_checkers'

namespace :svgcheck do
  desc 'Generate svgcheck outputs for test files'
  task :generate, [:mode] do |t, args|
    mode = args[:mode] || 'both'

    puts "🔧 Generating svgcheck outputs (mode: #{mode})..."

    checker = SvgConform::ExternalCheckers::Svgcheck::Checker.new

    unless checker.available?
      puts "❌ svgcheck not available. Please ensure Python 3 and svgcheck are installed."
      exit 1
    end

    generator = SvgConform::ExternalCheckers::Svgcheck::OutputGenerator.new
    test_files = find_test_files

    if test_files.empty?
      puts "❌ No test files found in svgcheck/svgcheck/Tests"
      exit 1
    end

    puts "📊 Found #{test_files.length} test files"

    success_count = 0
    error_count = 0

    test_files.each do |filename|
      puts "📄 Processing #{filename}..."

      begin
        results = generator.generate(filename, mode: mode.to_sym)

        if results.values.all? { |result| result[:success] }
          success_count += 1
          puts "  ✅ Success"
        else
          error_count += 1
          puts "  ❌ Failed"
          results.each do |result_mode, result|
            puts "    #{result_mode}: #{result[:error]}" unless result[:success]
          end
        end
      rescue => e
        error_count += 1
        puts "  ❌ Error: #{e.message}"
      end
    end

    puts "\n📈 GENERATION SUMMARY:"
    puts "  ✅ Successfully generated: #{success_count}"
    puts "  ❌ Failed: #{error_count}"
    puts "  📁 Output directory: spec/fixtures/svgcheck"
  end

  desc 'Compare svg_conform validation against svgcheck outputs'
  task :compare do
    puts "🔍 Comparing svg_conform validation against svgcheck outputs..."

    comparator = SvgConform::ExternalCheckers::Svgcheck::ReportComparator.new
    results = comparator.compare_all_test_files

    puts "\n📊 COMPARISON SUMMARY:"
    puts "  📄 Total files processed: #{results[:total_files]}"
    puts "  ✅ Matching reports: #{results[:matching]}"
    puts "  ❌ Different reports: #{results[:different]}"
    puts "  ⚠️  Errors: #{results[:errors]}"

    if results[:different] > 0
      puts "\n🔍 Files with differences:"
      results[:differences].each do |file, diff|
        puts "  #{file}: #{diff[:summary]}"
      end
    end
  end

  desc 'Validate profile configuration against svgcheck source'
  task :validate_profile do
    puts "🔍 Validating svg_1_2_rfc profile against svgcheck source..."

    validator = SvgConform::ExternalCheckers::Svgcheck::ProfileValidator.new
    results = validator.validate_profile('config/profiles/svg_1_2_rfc.yml')

    puts "\n📊 VALIDATION SUMMARY:"
    puts "  ✅ Matching configurations: #{results[:matches]}"
    puts "  ❌ Mismatched configurations: #{results[:mismatches]}"
    puts "  ⚠️  Missing configurations: #{results[:missing]}"

    if results[:issues].any?
      puts "\n🔍 Issues found:"
      results[:issues].each do |issue|
        puts "  #{issue[:type]}: #{issue[:message]}"
      end
    end
  end

  private

  def find_test_files
    test_dir = 'svgcheck/svgcheck/Tests'
    return [] unless Dir.exist?(test_dir)

    # Find all .svg and .xml files
    pattern = File.join(test_dir, '*.{svg,xml}')
    Dir.glob(pattern).map { |path| File.basename(path) }.sort
  end
end
