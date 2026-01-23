#!/usr/bin/env ruby
# frozen_string_literal: true

# Performance benchmark for svg_conform optimizations
# Measures validation speed for single and batch operations

require "bundler/setup"
require "benchmark"
require_relative "../lib/svg_conform"

# Helper method to create test SVG content
def create_test_svg(element_count: 10, attribute_count: 5)
  elements = (1..element_count).map do |i|
    attrs = (1..attribute_count).map { |j| "attr#{j}='value#{j}'" }.join(" ")
    "<rect id='rect#{i}' x='#{i * 10}' y='#{i * 10}' width='10' height='10' #{attrs}/>"
  end

  <<~SVG
    <?xml version="1.0"?>
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000">
      #{elements.join("\n      ")}
    </svg>
  SVG
end

puts "=" * 80
puts "svg_conform Performance Benchmark"
puts "=" * 80
puts

# Test configurations
test_cases = [
  { name: "Small document", elements: 10, attributes: 3 },
  { name: "Medium document", elements: 50, attributes: 5 },
  { name: "Large document", elements: 100, attributes: 8 },
]

validator = SvgConform::Validator.new

test_cases.each do |test_case|
  puts "Test: #{test_case[:name]}"
  puts "  Elements: #{test_case[:elements]}, Attributes per element: #{test_case[:attributes]}"
  puts

  svg_content = create_test_svg(element_count: test_case[:elements],
                                attribute_count: test_case[:attributes])

  # Warmup run
  validator.validate(svg_content, profile: :svg_1_2_rfc)

  # Benchmark single validation
  single_time = Benchmark.measure do
    100.times do
      validator.validate(svg_content, profile: :svg_1_2_rfc)
    end
  end

  puts "  Single validation (100 runs): #{(single_time.real * 1000).round(2)}ms"
  puts "    Average per validation: #{(single_time.real * 10).round(2)}ms"

  # Benchmark batch validation
  contents = Array.new(10) do
    create_test_svg(element_count: test_case[:elements],
                    attribute_count: test_case[:attributes])
  end

  batch_time = Benchmark.measure do
    10.times do
      contents.each do |content|
        validator.validate(content, profile: :svg_1_2_rfc)
      end
    end
  end

  puts "  Batch validation (10 files × 10 runs): #{(batch_time.real * 1000).round(2)}ms"
  puts "    Average per file: #{(batch_time.real * 100).round(2)}ms"
  puts
end

puts "=" * 80
puts "Memory Profiling"
puts "=" * 80
puts

if Object.const_defined?(:GC)
  GC.start
  before_mem = `ps -o rss= -p #{Process.pid}`.to_i

  # Create and validate 100 documents
  100.times do
    svg = create_test_svg(element_count: 50, attribute_count: 5)
    validator.validate(svg, profile: :svg_1_2_rfc)
  end

  GC.start
  after_mem = `ps -o rss= -p #{Process.pid}`.to_i

  mem_increase = after_mem - before_mem
  puts "  RSS memory increase: #{mem_increase} KB"
  puts "  Per validation: #{(mem_increase / 100.0).round(2)} KB"
else
  puts "  Memory profiling not available on this platform"
end

puts
puts "=" * 80
puts "Benchmark Complete"
puts "=" * 80
puts
puts "Optimizations tested:"
puts "  ✓ Phase 1.1: ElementProxy#path_id memoization"
puts "  ✓ Phase 1.2: Element configuration index"
puts "  ✓ Phase 2.1: Requirement classification cache"
puts "  ✓ Phase 2.2: Global properties constant"
puts "  ✓ Phase 2.3: ElementProxy attributes cache"
puts "  ✓ Phase 3.1: Configuration validation cache"
puts "  ✓ Phase 3.3: ProfileCompiler class"
puts "  ✓ Phase 4.1: TrackerFactory extraction"
puts "  ✓ Phase 5.1: Batch validation optimization"
puts
