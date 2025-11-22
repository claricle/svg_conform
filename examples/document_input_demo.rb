#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "svg_conform"
require "nokogiri"
require "moxml"

# Sample SVG content
svg_content = <<~SVG
  <?xml version="1.0" encoding="UTF-8"?>
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <rect id="box" width="10" height="10"/>
    </defs>
    <use href="#box" x="20" y="20" fill="black"/>
  </svg>
SVG

validator = SvgConform::Validator.new(mode: :sax)

puts "=" * 60
puts "SvgConform: Document Object Input Demo"
puts "=" * 60

# 1. String input (backward compatible)
puts "\n1. String Input (Traditional)"
puts "-" * 60
result = validator.validate(svg_content, profile: :metanorma)
puts "Valid: #{result.valid?}"
puts "Errors: #{result.errors.size}"
puts "Available IDs: #{result.available_ids.map(&:id_value).join(', ')}"

# 2. Moxml Document input
puts "\n2. Moxml Document Input"
puts "-" * 60
moxml_doc = Moxml.new.parse(svg_content)
result = validator.validate(moxml_doc, profile: :metanorma)
puts "Valid: #{result.valid?}"
puts "Errors: #{result.errors.size}"
puts "Available IDs: #{result.available_ids.map(&:id_value).join(', ')}"

# 3. Moxml Element input
puts "\n3. Moxml Element Input"
puts "-" * 60
moxml_element = moxml_doc.root
result = validator.validate(moxml_element, profile: :metanorma)
puts "Valid: #{result.valid?}"
puts "Available IDs: #{result.available_ids.map(&:id_value).join(', ')}"

# 4. Nokogiri Document input
puts "\n4. Nokogiri Document Input"
puts "-" * 60
nokogiri_doc = Nokogiri::XML(svg_content)
result = validator.validate(nokogiri_doc, profile: :metanorma)
puts "Valid: #{result.valid?}"
puts "Available IDs: #{result.available_ids.map(&:id_value).join(', ')}"

# 5. Nokogiri Element input (Metanorma use case)
puts "\n5. Nokogiri Element Input (Metanorma Integration)"
puts "-" * 60
nokogiri_element = nokogiri_doc.root
puts "Element class: #{nokogiri_element.class.name}"
result = validator.validate(nokogiri_element, profile: :metanorma)
puts "Valid: #{result.valid?}"
puts "Available IDs: #{result.available_ids.map(&:id_value).join(', ')}"

# 6. Performance comparison
puts "\n6. Performance Comparison"
puts "-" * 60
puts "Old way (metanorma):"
puts "  nokogiri_element.to_xml  →  validator.validate(string)"
puts "  = TWO conversions (serialize + parse)"
puts
puts "New way:"
puts "  validator.validate(nokogiri_element)"
puts "  = ONE conversion (serialize for SAX only)"
puts
puts "Benefit: 50% reduction in serialization/parsing overhead!"

# 7. Reference manifest with document input
puts "\n7. Reference Manifest from Document Objects"
puts "-" * 60
result = validator.validate(nokogiri_element, profile: :metanorma)
manifest = result.reference_manifest

puts "Total IDs defined: #{manifest.available_ids.size}"
puts "Internal references: #{manifest.internal_references.size}"
puts "External references: #{manifest.external_references.size}"

if result.unresolved_internal_references.any?
  puts "\nUnresolved references:"
  result.unresolved_internal_references.each do |ref|
    puts "  - #{ref.value}"
  end
else
  puts "\nAll internal references resolved ✓"
end

puts "\n#{'=' * 60}"
puts "Demo complete!"
puts "=" * 60
