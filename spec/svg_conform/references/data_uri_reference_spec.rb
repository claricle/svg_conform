# frozen_string_literal: true

require "spec_helper"
require "base64"
require "zlib"

RSpec.describe SvgConform::References::DataUriReference do
  def ref(value)
    SvgConform::References::ReferenceClassifier.classify(
      value, element_name: "image", attribute_name: "href"
    )
  end

  def chunk(type, data)
    [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
  end

  let(:png) do
    "\x89PNG\r\n\x1A\n".b +
      chunk("IHDR", [1, 1, 8, 2, 0, 0, 0].pack("NNCCCCC")) +
      chunk("IDAT", Zlib::Deflate.deflate("\x00\xFF\x00\x00".b)) +
      chunk("IEND", "")
  end
  let(:jpeg) { "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\xFF\xD9".b }

  it "decodes base64 and percent-encoded payloads to the same bytes" do
    pct = png.each_byte.map { |b| format("%%%02X", b) }.join
    expect(ref("data:image/png;base64,#{Base64.strict_encode64(png)}").payload)
      .to eq(png)
    expect(ref("data:image/png,#{pct}").payload).to eq(png)
  end

  it "reports base64? and a normalized media type" do
    r = ref("data:IMAGE/PNG;base64,AAAA")
    expect(r.base64?).to be true
    expect(r.normalized_media_type).to eq("image/png")
    expect(ref("data:,hello").normalized_media_type).to eq("text/plain")
  end

  it "accepts well-formed PNG and JPEG payloads" do
    expect(ref("data:image/png;base64,#{Base64.strict_encode64(png)}")
      .raster_error).to be_nil
    expect(ref("data:image/jpeg;base64,#{Base64.strict_encode64(jpeg)}")
      .raster_error).to be_nil
  end

  {
    "data:image/png;base64," => /empty/,
    "data:image/png;base64,!!!" => /malformed base64/,
    "data:image/png,%G1" => /percent/,
    "data:image/png" => /separator/,
    "data:image/png;base64,bm90IGEgcG5n" => /not a PNG/,
    "data:image/jpeg;base64,bm90IGEganBn" => /not a JPEG/,
  }.each do |value, pattern|
    it "rejects #{value}" do
      expect(ref(value).raster_error).to match(pattern)
    end
  end

  it "detects PNG checksum corruption and truncation" do
    bad = png.dup
    bad.setbyte(20, bad.getbyte(20) ^ 0xFF)
    expect(ref("data:image/png;base64,#{Base64.strict_encode64(bad)}")
      .raster_error).to match(/checksum|IHDR/)
    cut = png.byteslice(0, png.bytesize - 6)
    expect(ref("data:image/png;base64,#{Base64.strict_encode64(cut)}")
      .raster_error).not_to be_nil
  end

  it "stays internal in validation_scope" do
    expect(ref("data:image/png,x").validation_scope).to eq(:internal)
  end
end
