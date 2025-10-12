# frozen_string_literal: true

# spec/support/xml_matchers.rb
# RSpec::Matchers.define :be_equivalent_to do |expected|
#   match do |actual|
#     normalize_xml(actual) == normalize_xml(expected)
#   end

#   failure_message do |actual|
#     "expected XML to be equivalent to:\n#{normalize_xml(expected)}\n\nbut was:\n#{normalize_xml(actual)}"
#   end

#   def normalize_xml(xml)
#     xml.to_s.gsub(/>\s+</, '><').strip
#   end
# end

RSpec::Matchers.define :have_xpath do |xpath, text|
  match do |xml_node|
    nodes = xml_node.xpath(xpath)
    text.nil? ? !nodes.empty? : nodes.any? { |node| node.text == text }
  end

  failure_message do |_xml_node|
    "expected to find xpath #{xpath} #{text ? "with text '#{text}'" : ""}"
  end
end
