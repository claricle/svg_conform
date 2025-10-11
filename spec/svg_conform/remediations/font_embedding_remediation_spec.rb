# frozen_string_literal: true

require "spec_helper"

RSpec.describe SvgConform::Remediations::FontEmbeddingRemediation do
  describe "configuration" do
    it "can be instantiated with basic parameters" do
      remediation = described_class.new(
        id: "font_embedding",
        description: "Test",
      )
      expect(remediation).to respond_to(:apply)
    end

    it "responds to apply method" do
      remediation = described_class.new(id: "test", description: "Test")
      expect(remediation).to respond_to(:apply)
    end
  end
end
