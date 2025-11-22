# frozen_string_literal: true

require "spec_helper"

RSpec.describe "IdReferenceRequirement" do
  let(:validator) { SvgConform::Validator.new(mode: :sax) }

  # SVG with a reference to undefined ID 'missing_id'
  let(:svg_with_error) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
        <a href="#missing_id">
          <rect x="10" y="10" width="80" height="80"/>
        </a>
      </svg>
    SVG
  end

  # SVG with valid references only
  let(:svg_without_error) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
        <rect id="valid_id" x="10" y="10" width="80" height="80"/>
        <a href="#valid_id">
          <text x="50" y="50">Link</text>
        </a>
      </svg>
    SVG
  end

  it "does not leak state from first validation to second validation" do
    # First validation: SVG with reference error
    result1 = validator.validate(svg_with_error, profile: :metanorma)

    # Verify first validation caught the error
    expect(result1.errors.map(&:message)).to include(
      match(/Reference to undefined ID 'missing_id'/),
    )

    # Second validation: SVG without reference errors
    result2 = validator.validate(svg_without_error, profile: :metanorma)

    # Verify second validation does NOT report errors from first validation
    error_messages = result2.errors.map(&:message).join("\n")
    expect(error_messages).not_to include("missing_id"),
                                  "State leaked from first validation! Second validation should not mention 'missing_id'"

    # Second validation should have no errors (or at least no reference errors)
    reference_errors = result2.errors.select do |e|
      e.message.include?("Reference to undefined")
    end
    expect(reference_errors).to be_empty,
                                "Second validation should have no reference errors, but got: #{reference_errors.map(&:message)}"
  end

  it "handles multiple sequential validations correctly" do
    # Run multiple validations to ensure state resets each time
    results = []

    # Alternate between error and no-error SVGs
    3.times do
      results << validator.validate(svg_with_error, profile: :metanorma)
      results << validator.validate(svg_without_error, profile: :metanorma)
    end

    # Check that error pattern is consistent
    results.each_with_index do |result, i|
      if i.even?
        # Should have error (svg_with_error)
        expect(result.errors.map(&:message)).to include(
          match(/Reference to undefined ID 'missing_id'/),
        )
      else
        # Should NOT have error about missing_id (svg_without_error)
        error_messages = result.errors.map(&:message).join("\n")
        expect(error_messages).not_to include("missing_id")
      end
    end
  end

  it "resets state when using the same profile instance" do
    # Get profile instance
    profile = SvgConform::Profiles.get(:metanorma)

    # Run two validations using the same profile
    validator.validate(svg_with_error, profile: profile)
    result2 = validator.validate(svg_without_error, profile: profile)

    # Second validation should not have first validation's errors
    error_messages = result2.errors.map(&:message).join("\n")
    expect(error_messages).not_to include("missing_id")
  end
end
