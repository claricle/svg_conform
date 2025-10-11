# frozen_string_literal: true

require "spec_helper"

RSpec.describe SvgConform::Requirements::NoExternalImagesRequirement do
  describe "configuration" do
    it "can be instantiated with basic parameters" do
      requirement = described_class.new(
        id: "no_external_images",
        description: "Test",
      )
      expect(requirement).to respond_to(:check)
    end

    it "responds to check method" do
      requirement = described_class.new(id: "test", description: "Test")
      expect(requirement).to respond_to(:check)
    end
  end
end
