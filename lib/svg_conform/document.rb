# frozen_string_literal: true

require 'moxml'

module SvgConform
  # Wrapper around Moxml document for SVG validation
  class Document
    attr_reader :file_path, :moxml_document

    def initialize(content_or_path)
      if File.exist?(content_or_path.to_s)
        @file_path = content_or_path
        @content = File.read(@file_path)
      else
        @file_path = nil
        @content = content_or_path
      end

      parse_document
    end

    def self.from_file(file_path)
      new(file_path)
    end

    def self.from_content(content)
      new(content)
    end

    def root
      @moxml_document.root
    end

    def elements
      @moxml_document.elements
    end

    def xpath(path, namespaces = {})
      @moxml_document.xpath(path, namespaces)
    end

    def traverse(&block)
      traverse_node(root, &block) if root
    end

    def svg_elements
      # Handle both default namespace and prefixed namespace
      if has_svg_namespace_prefix?
        xpath('//svg:*', { 'svg' => 'http://www.w3.org/2000/svg' }).select { |node| node.respond_to?(:name) }
      else
        xpath("//*[namespace-uri()='http://www.w3.org/2000/svg']").select { |node| node.respond_to?(:name) }
      end
    end

    def to_xml
      @moxml_document.to_xml
    end

    def dup
      Document.from_content(to_xml)
    end

    def valid_xml?
      !@moxml_document.nil?
    rescue StandardError
      false
    end

    def namespace_uri
      root&.namespace&.uri
    end

    def svg_namespace?
      namespace_uri == 'http://www.w3.org/2000/svg'
    end

    def has_svg_namespace_prefix?
      @content.include?('xmlns:svg=') || @content.include?('svg:')
    end

    def has_viewbox?
      root&.attribute('viewBox')
    end

    def viewbox
      root&.attribute('viewBox')&.value
    end

    def width
      root&.attribute('width')&.value
    end

    def height
      root&.attribute('height')&.value
    end

    def version
      root&.attribute('version')&.value
    end

    # Find all elements with a specific name
    def find_elements(name)
      if has_svg_namespace_prefix?
        xpath("//svg:#{name}", { 'svg' => 'http://www.w3.org/2000/svg' })
      else
        xpath("//#{name}[namespace-uri()='http://www.w3.org/2000/svg']")
      end
    end

    # Find all elements with style attributes
    def elements_with_style
      xpath('//*[@style]')
    end

    # Find all elements with specific attributes
    def elements_with_attribute(attr_name)
      xpath("//*[@#{attr_name}]")
    end

    # Get all unique element names in the document
    def element_names
      svg_elements.map(&:name).uniq.sort
    end

    # Get all unique attribute names in the document
    def attribute_names
      attributes = []
      traverse do |node|
        attributes.concat(node.attributes.keys) if node.respond_to?(:attributes)
      end
      attributes.uniq.sort
    end

    # Check if document contains external references
    def has_external_references?
      # Check for external stylesheets
      link_elements = if has_svg_namespace_prefix?
                        xpath('//svg:link[@rel="stylesheet"]', { 'svg' => 'http://www.w3.org/2000/svg' })
                      else
                        xpath('//link[@rel="stylesheet"][namespace-uri()="http://www.w3.org/2000/svg"]')
                      end
      return true if link_elements.any?

      # Check for @import in style elements
      style_elements = if has_svg_namespace_prefix?
                         xpath('//svg:style', { 'svg' => 'http://www.w3.org/2000/svg' })
                       else
                         xpath("//style[namespace-uri()='http://www.w3.org/2000/svg']")
                       end

      style_elements.each do |style|
        content = style.text
        return true if content&.include?('@import')
      end

      # Check for external references in style attributes
      elements_with_style.each do |element|
        style_value = element.attribute('style')&.value
        return true if style_value&.include?('url(')
      end

      false
    end

    private

    def parse_document
      begin
        # Create a Moxml context and parse the document
        context = Moxml.new
        @moxml_document = context.parse(@content)
      rescue StandardError => e
        raise ParseError, "Failed to parse SVG document: #{e.message}"
      end

      raise ParseError, 'Document could not be parsed' unless @moxml_document

      raise ParseError, 'Document has no root element' unless root

      # Check if root element is SVG (handle both namespaced and non-namespaced)
      root_name = root.name
      root_namespace = root.namespace&.uri

      # Accept if element name is "svg" regardless of namespace
      # or if it's in the SVG namespace
      return if root_name == 'svg' || root_namespace == 'http://www.w3.org/2000/svg'

      raise ParseError, "Root element must be 'svg', found '#{root_name}'"
    end

    def traverse_node(node, &block)
      yield node if block_given?

      return unless node.respond_to?(:children)

      node.children.each do |child|
        traverse_node(child, &block)
      end
    end
  end
end
