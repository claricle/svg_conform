# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Lucid Fix Profile" do
  let(:lucid_fix_profile_path) { "config/profiles/lucid_fix.yml" }

  describe "profile loading" do
    it "loads the lucid fix profile successfully" do
      profile = SvgConform::Profile.load_from_file(lucid_fix_profile_path)
      expect(profile).not_to be_nil
      expect(profile.name).to eq("lucid_fix")
    end

    it "includes requirements specific to Lucid diagrams" do
      profile = SvgConform::Profile.load_from_file(lucid_fix_profile_path)
      expect(profile.requirements).to be_an(Array)
      expect(profile.requirements).not_to be_empty
    end

    it "has description indicating Lucid-specific fixes" do
      profile = SvgConform::Profile.load_from_file(lucid_fix_profile_path)
      expect(profile.description).to be_a(String)
    end
  end

  describe "validation with lucid fixtures" do
    let(:lucid_fixtures_dir) { "spec/fixtures/lucid" }

    it "handles lucid-specific SVG patterns" do
      skip "Lucid fixtures not found" unless Dir.exist?(lucid_fixtures_dir)

      input_files = Dir.glob(File.join(lucid_fixtures_dir, "inputs/*.svg"))
      skip "No lucid input files found" if input_files.empty?

      profile = SvgConform::Profile.load_from_file(lucid_fix_profile_path)
      input_file = input_files.first

      document = SvgConform::Document.from_file(input_file)
      result = profile.validate(document)

      expect(result).to respond_to(:valid?)
      expect(result).to respond_to(:errors)
    end
  end
end
