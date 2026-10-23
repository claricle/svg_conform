# frozen_string_literal: true

require "spec_helper"
require "base64"

RSpec.describe SvgConform::Requirements::ExternalReferencesRequirement do
  let(:requirement) do
    described_class.new(id: "ext", citation_uri: "https://example.test/cite")
  end
  let(:profile) { SvgConform::Profile.new(name: "x", requirements: [requirement]) }
  let(:ns) { 'xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"' }

  def svg(body, pre: "")
    %(#{pre}<svg #{ns} viewBox="0 0 1 1">#{body}</svg>)
  end

  def dom(xml)
    profile.validate(SvgConform::Document.from_content(xml))
  end

  def sax(xml)
    SvgConform::SaxDocument.from_content(xml).validate_with_profile(profile)
  end

  def b64_svg(inner)
    "data:image/svg+xml;base64,#{Base64.strict_encode64(inner)}"
  end

  {
    "same-document href" => ['<use href="#a"/>', 0],
    "same-document xlink:href" => ['<use xlink:href="#a"/>', 0],
    "http href" => ['<image href="http://e.test/a.png"/>', 1],
    "xlink http href" => ['<image xlink:href="https://e.test/a.png"/>', 1],
    "anchor to web" => ['<a href="https://e.test/">x</a>', 1],
    "presentation url" => ['<rect fill="url(other.svg#g)"/>', 1],
    "presentation fragment" => ['<rect fill="url(#g)"/>', 0],
    "style attribute url" => ['<rect style="fill:url(&quot;x.svg#g&quot;)"/>', 1],
    "style element import string" => ['<style>@import "a.css";</style>', 1],
    "style element import url counted once" => ["<style>@import url(a.css);</style>", 1],
    "style element url" => ["<style>a{fill:url(a.svg#x)}</style>", 1],
    "css comment ignored" => ["<style>/* url(a.svg) */ a{fill:red}</style>", 0],
    "escaped url function" => ['<rect style="fill:u\\72l(https://e.test/x.png)"/>', 1],
    "escaped url function uppercase hex" => ['<rect style="fill:\\55RL(https://e.test/x.png)"/>', 1],
    "escaped url in presentation attribute" => ['<rect fill="u\\72l(https://e.test/x.png)"/>', 1],
    "escaped url with quoted string" => ['<rect style="fill:u\\72l(\'https://e.test/x.png\')"/>', 1],
    "escaped characters inside the url" => ['<rect style="fill:url(\\68ttps://e.test/x.png)"/>', 1],
    "escaped import string" => ['<style>@\\69mport "a.css";</style>', 1],
    "escaped import url" => ['<style>@imp\\6frt url(a.css);</style>', 1],
    "escaped import with escaped url" => ['<style>@\\69mport u\\72l(a.css);</style>', 1],
    "url text inside a css string is not a reference" => ['<style>a{content:"url(a.svg)"}</style>', 0],
    "escaped url with same-document fragment" => ['<rect style="fill:u\\72l(#g)"/>', 0],
    "javascript scheme" => ['<a href="javascript:x()">x</a>', 1],
  }.each do |label, (body, count)|
    it "#{label}: #{count} finding(s) through DOM and SAX" do
      xml = svg(body)
      expect(dom(xml).errors.size).to eq(count)
      expect(sax(xml).errors.map(&:message)).to eq(dom(xml).errors.map(&:message))
    end
  end

  it "reports xml-stylesheet processing instructions from the source" do
    xml = svg("", pre: %(<?xml-stylesheet href="a.css"?>))
    expect(dom(xml).errors.size).to eq(1)
    expect(sax(xml).errors.size).to eq(1)
  end

  it "uses the requirement id and citation in error data" do
    error = sax(svg('<image href="//e.test/a.png"/>')).errors.first
    expect(error.requirement_id).to eq("ext")
    expect(error.data).to include(citation: "https://example.test/cite",
                                  reference_type: "RelativePathReference")
  end

  describe "nested SVG data URLs" do
    let(:plain) { '<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>' }

    it "accepts a self-contained SVG" do
      expect(sax(svg(%(<image href="#{b64_svg(plain)}"/>))).errors).to be_empty
    end

    it "rejects malformed XML, non-svg roots and external entities" do
      ["<svg><g></svg>", "<html/>",
       %(<!DOCTYPE svg SYSTEM "http://e.test/x.dtd"><svg/>)].each do |bad|
        errors = sax(svg(%(<image href="#{b64_svg(bad)}"/>))).errors
        expect(errors.size).to eq(1), bad
      end
    end

    it "reports nested external content with a JSON-safe reason" do
      inner = '<svg xmlns="http://www.w3.org/2000/svg"><image href="http://e.test/a"/></svg>'
      error = dom(svg(%(<image href="#{b64_svg(inner)}"/>))).errors.first
      expect(error.data[:reason]).to match(/nested href 'http:\/\/e.test\/a'/)
      expect { JSON.generate(error.data) }.not_to raise_error
    end

    it "limits nesting depth" do
      nest = plain
      4.times do
        nest = %(<svg xmlns="http://www.w3.org/2000/svg"><image href="#{b64_svg(nest)}"/></svg>)
      end
      error = sax(svg(%(<image href="#{b64_svg(nest)}"/>))).errors.first
      expect(error.data[:reason]).to include("nesting exceeds 3")
    end
  end

  it "ignores empty references like the classifier does" do
    expect(sax(svg('<image href=""/>')).errors).to be_empty
  end
end
