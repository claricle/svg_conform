# frozen_string_literal: true

require "nokogiri"
require_relative "sax_validation_handler"

module SvgConform
  # SAX-based document for streaming validation
  # Provides high-performance validation for large SVG files
  # without loading entire DOM tree into memory
  class SaxDocument
    attr_reader :file_path, :content

    def self.from_file(file_path)
      new(File.read(file_path), file_path)
    end

    def self.from_content(content)
      new(content, nil)
    end

    def initialize(content, file_path = nil)
      @content = content
      @file_path = file_path
    end

    # Validate using SAX streaming parser
    def validate_with_profile(profile)
      handler = SaxValidationHandler.new(profile)
      parser = Nokogiri::XML::SAX::Parser.new(handler)
      
      begin
        parser.parse(@content)
      rescue StandardError => e
        # Handle parse errors
        handler.add_parse_error(e)
      end
      
      handler.result
    end

    # For compatibility - convert to DOM when needed
    def to_dom
      Document.from_content(@content)
    end
  end
end
