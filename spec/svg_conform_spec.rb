# frozen_string_literal: true

RSpec.describe SvgConform do
  it 'has a version number' do
    expect(SvgConform::VERSION).not_to be nil
  end

  it 'validates SVG documents' do
    svg_content = <<~SVG
      <svg width="100" height="100">
        <rect x="10" y="10" width="50" height="50" fill="red"/>
      </svg>
    SVG

    validator = SvgConform::Validator.new
    result = validator.validate(svg_content, profile: :svg_1_2_rfc)

    expect(result).to respond_to(:valid?)
    expect(result).to respond_to(:errors)
    expect(result).to respond_to(:warnings)
  end

  it 'loads profiles correctly' do
    svg_1_2_rfc_profile = SvgConform::Profiles.get(:svg_1_2_rfc)
    expect(svg_1_2_rfc_profile).not_to be_nil
    expect(svg_1_2_rfc_profile.requirements).not_to be_empty

    css_profile = SvgConform::Profiles.get(:no_external_css)
    expect(css_profile).not_to be_nil
    expect(css_profile.requirements).not_to be_empty
  end
end
