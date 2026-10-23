# frozen_string_literal: true

require "lutaml/model"
require "zlib"

module SvgConform
  module References
    # Base class for all reference types
    class BaseReference < Lutaml::Model::Serializable
      attribute :value, :string
      attribute :element_name, :string
      attribute :attribute_name, :string
      attribute :line_number, :integer
      attribute :column_number, :integer

      yaml do
        map "value", to: :value
        map "element_name", to: :element_name
        map "attribute_name", to: :attribute_name
        map "line_number", to: :line_number
        map "column_number", to: :column_number
      end

      json do
        map "value", to: :value
        map "element_name", to: :element_name
        map "attribute_name", to: :attribute_name
        map "line_number", to: :line_number
        map "column_number", to: :column_number
      end

      # Abstract method - defines validation scope
      def validation_scope
        raise NotImplementedError, "Subclasses must define validation scope"
      end

      # Can this reference be validated internally by svg_conform?
      def internally_validatable?
        validation_scope == :internal
      end

      # Should this be deferred to consumer for validation?
      def requires_consumer_validation?
        validation_scope == :external
      end

      def to_h
        {
          type: self.class.name.split("::").last,
          value: value,
          element_name: element_name,
          attribute_name: attribute_name,
          line_number: line_number,
          column_number: column_number,
          validation_scope: validation_scope,
        }
      end
    end

    # Internal SVG element reference (e.g., #element-id)
    class InternalFragmentReference < BaseReference
      def validation_scope
        :internal
      end

      def target_id
        value.sub(/^#/, "")
      end
    end

    # External URL reference (http://, https://)
    class ExternalUrlReference < BaseReference
      def validation_scope
        :external
      end

      def protocol
        require "uri"
        URI.parse(value).scheme
      rescue StandardError
        nil
      end
    end

    # URN reference (urn:*)
    class UrnReference < BaseReference
      def validation_scope
        :external
      end

      def namespace
        value.split(":")[1]
      rescue StandardError
        nil
      end
    end

    # Relative path reference (could be internal or external depending on context)
    class RelativePathReference < BaseReference
      def validation_scope
        :external
      end

      def has_fragment?
        value.include?("#")
      end

      def path_component
        value.split("#").first
      end

      def fragment_component
        parts = value.split("#")
        parts.size > 1 ? parts.last : nil
      end
    end

    # Data URI reference (data:*)
    class DataUriReference < BaseReference
      PARSE = /\Adata:(?<head>[^,]*),(?<body>.*)\z/mi
      PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze

      def validation_scope
        :internal
      end

      def media_type
        # Extract media type from data URI
        match = value.match(%r{^data:([^;,]+)})
        match ? match[1] : nil
      end

      # Lowercased media type, defaulting per RFC 2397 when omitted
      def normalized_media_type
        (media_type || "text/plain").strip.downcase
      end

      def base64?
        match = PARSE.match(value)
        return false unless match

        match[:head].split(";").map { |part| part.strip.downcase }
          .include?("base64")
      end

      # Raw payload bytes (binary string), or nil when #decode_error is set
      def payload
        decode unless defined?(@payload)
        @payload
      end

      # Why the payload cannot be decoded, or nil
      def decode_error
        decode unless defined?(@payload)
        @decode_error
      end

      # Why the decoded raster payload is not a PNG/JPEG file, or nil.
      # Only meaningful for image/png and image/jpeg media types.
      def raster_error
        return decode_error if decode_error
        return "empty payload" if payload.empty?

        case normalized_media_type
        when "image/png" then png_error(payload)
        when "image/jpeg" then jpeg_error(payload)
        end
      end

      private

      def decode
        @payload = nil
        @decode_error = nil
        match = PARSE.match(value)
        unless match
          @decode_error = "missing ',' separator"
          return
        end

        body = match[:body]
        if base64?
          decode_base64(body)
        else
          decode_percent(body)
        end
      end

      def decode_base64(body)
        require "base64"
        @payload = Base64.strict_decode64(percent_unescape(body).delete("\s"))
      rescue ArgumentError
        @decode_error = "malformed base64 payload"
      end

      def decode_percent(body)
        @payload = percent_unescape(body)
      rescue ArgumentError
        @decode_error = "malformed percent-encoding"
      end

      def percent_unescape(text)
        raise ArgumentError, "bad escape" if text.match?(/%(?!\h\h)/)

        text.b.gsub(/%(\h\h)/) { Regexp.last_match(1).hex.chr }
      end

      def png_error(bytes)
        return "not a PNG file" unless bytes.start_with?(PNG_SIGNATURE)

        offset = PNG_SIGNATURE.bytesize
        first = true
        while offset + 12 <= bytes.bytesize
          length = bytes.byteslice(offset, 4).unpack1("N")
          type = bytes.byteslice(offset + 4, 4)
          return "PNG must start with IHDR" if first && type != "IHDR"
          return "truncated PNG chunk" if offset + 12 + length > bytes.bytesize

          data = bytes.byteslice(offset + 4, 4 + length)
          crc = bytes.byteslice(offset + 8 + length, 4).unpack1("N")
          return "PNG chunk checksum mismatch" unless Zlib.crc32(data) == crc
          return nil if type == "IEND"

          first = false
          offset += 12 + length
        end
        "PNG is missing IEND"
      end

      def jpeg_error(bytes)
        return "not a JPEG file" unless bytes.start_with?("\xFF\xD8\xFF".b)
        return "truncated JPEG" unless bytes.end_with?("\xFF\xD9".b)

        nil
      end
    end
  end
end
