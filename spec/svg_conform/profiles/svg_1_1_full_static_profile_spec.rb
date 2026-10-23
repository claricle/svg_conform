# frozen_string_literal: true

require "spec_helper"
require "svg_conform/profile_compiler"
require "open3"
require "json"

# Path is fixed by the card; the cop expects svg11_ instead of svg_1_1_.
RSpec.describe "svg_1_1_full_static profile" do # rubocop:disable RSpec/DescribeClass
  let(:profile) { SvgConform::Profiles.get("svg_1_1_full_static") }
  let(:fixtures) { File.expand_path("../../fixtures/profiles/svg_1_1_full_static", __dir__) }
  let(:matrix) do
    {
      "svg11.document.xml" => "https://www.w3.org/TR/2011/REC-SVG11-20110816/conform.html#ConformingSVGDocuments",
      "svg11.document.root" => "https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#SVGElement",
      "svg11.document.version" => "https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#SVGElementVersionAttribute",
      "svg11.document.grammar" => "https://www.w3.org/TR/2011/REC-SVG11-20110816/conform.html#ConformingSVGDocuments",
      "svg11.document.css2" => "https://www.w3.org/TR/2008/REC-CSS2-20080411/grammar.html",
      "svg11.document.xml_stylesheet" => "https://www.w3.org/TR/1999/REC-xml-stylesheet-19990629/",
      "svg11.processing.script" => "https://www.w3.org/TR/2011/REC-SVG11-20110816/conform.html#ConformingSVGViewers",
      "svg11.processing.animation" => "https://www.w3.org/TR/2011/REC-SVG11-20110816/conform.html#ConformingSVGViewers",
      "svg11.processing.interaction" => "https://www.w3.org/TR/2011/REC-SVG11-20110816/conform.html#ConformingSVGViewers",
    }
  end
  let(:invalid_cases) do
    {
      "malformed-xml" => "svg11.document.xml",
      "wrong-namespace" => "svg11.document.root",
      "wrong-version" => "svg11.document.version",
      "dtd-content-model" => "svg11.document.grammar",
      "dtd-attribute" => "svg11.document.grammar",
      "css-grammar" => "svg11.document.css2",
      "xml-stylesheet" => "svg11.document.xml_stylesheet",
      "script" => "svg11.processing.script",
      "animation" => "svg11.processing.animation",
      "interaction" => "svg11.processing.interaction",
    }
  end

  def fixture(kind, name)
    File.join(fixtures, kind, "#{name}.svg")
  end

  def sax_errors(path)
    SvgConform::SaxDocument.from_file(path).validate_with_profile(profile).errors
  end

  def dom_errors(path)
    profile.validate(SvgConform::Document.from_file(path)).errors
  end

  def ids(errors)
    errors.map(&:requirement_id).uniq.sort - ["parse_error"]
  end

  it "is listed, opt-in and does not change the default profile" do
    expect(SvgConform::Profiles.available_profiles).to include(:svg_1_1_full_static)
    expect(profile.name).to eq("svg_1_1_full_static")
    expect(profile.specification_uri)
      .to eq("https://www.w3.org/TR/2011/REC-SVG11-20110816/")
    expect(SvgConform::Validator.new.method(:validate).parameters)
      .to include(%i[key profile])
    expect(SvgConform::Validator.instance_method(:validate_file)
      .parameters).to include(%i[key profile])
    expect(profile.remediations.to_a).to be_empty
  end

  it "covers the nine stable ids with their normative citations" do
    declared = profile.requirements.flat_map do |req|
      req.respond_to?(:categories) ? req.categories.map { |c| [c.id, c.citation] } : [[req.id, req.citation_uri]]
    end
    expect(declared.to_h).to eq(matrix)
  end

  it "builds through the existing class map and compiler" do
    expect(SvgConform::Profile::REQUIREMENTS_CLASS_MAP)
      .to include("Svg11DocumentRequirement", "ProcessingFeaturesRequirement")
    compiled = SvgConform::ProfileCompiler.compile("svg_1_1_full_static")
    expect(compiled.requirements.map { |req| req.class.name.split("::").last }.uniq)
      .to eq(%w[Svg11DocumentRequirement ProcessingFeaturesRequirement])
  end

  %w[minimal-full css xml-stylesheet foreign-metadata].each do |name|
    it "accepts valid/#{name}.svg identically in DOM and SAX" do
      path = fixture("valid", name)
      expect(dom_errors(path)).to be_empty
      expect(sax_errors(path)).to be_empty
    end
  end

  it "rejects each invalid fixture with the expected id in DOM and SAX" do
    invalid_cases.each do |name, id|
      path = fixture("invalid", name)
      sax = ids(sax_errors(path))
      expect(sax).to include(id), name
      if name == "malformed-xml"
        # DOM cannot build a document from malformed XML at all.
        expect { SvgConform::Document.from_file(path) }
          .to raise_error(SvgConform::ParseError)
      else
        expect(ids(dom_errors(path))).to eq(sax), name
      end
    end
  end

  it "gives every error a normative citation, through issues and LensCore" do
    invalid_cases.each_key do |name|
      result = SvgConform::SaxDocument.from_file(fixture("invalid", name)).validate_with_profile(profile)
      cited = result.errors.reject { |e| e.requirement_id == "parse_error" }
      expect(cited).not_to be_empty
      cited.each do |error|
        expect(matrix.values).to include(error.data[:citation]), "#{name} #{error.requirement_id}"
      end
      report = SvgConform::Diagnostics::LensCoreAdapter.call(result)
      report.diagnostics.each do |diag|
        next if diag.requirement_id == "parse_error"

        expect(diag.citations.map(&:uri) & matrix.values).not_to be_empty
      end
    end
  end

  it "validates a file input and a string input identically" do
    path = fixture("invalid", "wrong-version")
    from_string = SvgConform::SaxDocument.from_content(File.read(path))
      .validate_with_profile(profile)
    expect(ids(from_string.errors)).to eq(ids(sax_errors(path)))
    dom_string = profile.validate(SvgConform::Document.from_content(File.read(path)))
    expect(ids(dom_string.errors)).to eq(ids(from_string.errors))
  end

  it "does not claim Tiny or Basic and offers no remediation" do
    expect(profile.description).not_to match(/tiny|basic/i)
    expect(profile.remediation_count).to eq(0)
  end

  it "runs through the CLI check command and prints JSON" do
    out, status = Open3.capture2e(
      "bundle", "exec", "exe/svg_conform", "check",
      fixture("valid", "minimal-full"), "--profile", "svg_1_1_full_static",
      "--format", "json"
    )
    expect(status.exitstatus).to eq(0), out
    expect(JSON.parse(out[/\{.*\}/m])).to be_a(Hash)
  end
end
