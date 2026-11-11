require "spec_helper"

require "svg_conform/errors/validation_issue"

RSpec.describe SvgConform::Errors::ValidationIssue do
  let(:node) { Struct.new(:name, :line, :column).new("g", 1, 1) }

  def issue_for(requirement_id, message)
    described_class.new(
      type: :error,
      rule: Struct.new(:id).new(requirement_id),
      node: node,
      message: message,
    )
  end

  # metanorma's svg_error drops :reference_violation entries (the separate
  # reference pass covers them); a misclassification here silently deletes
  # profile verdicts from downstream logs (#133).
  it "classifies reference requirements by the whole id token" do
    expect(issue_for("id_references", "broken id reference").violation_type)
      .to eq(:reference_violation)
    expect(issue_for("id_collection", "collected").violation_type)
      .to eq(:reference_violation)
    expect(issue_for("external_references", "external reference").violation_type)
      .to eq(:reference_violation)
  end

  it "does not misclassify ids that merely contain the substring id" do
    expect(issue_for("namespace_validation", "namespace issue").violation_type)
      .to eq(:namespace_violation)
    expect(issue_for("link_validation", "bad link").violation_type)
      .to eq(:unknown_violation)
    expect(issue_for("allowed_elements", "Attribute 'opacity' is not allowed").violation_type)
      .to eq(:unknown_violation)
  end

  it "keeps the message-based classification anchored on reference wording" do
    expect(issue_for("unknown_rule", "broken reference to #missing").violation_type)
      .to eq(:reference_violation)
    expect(issue_for("unknown_rule", "broken href target").violation_type)
      .to eq(:reference_violation)
  end

  it "classifies the other requirement families as before" do
    expect(issue_for("forbidden_content", "Attribute 'fill' is not allowed").violation_type)
      .to eq(:content_violation)
    expect(issue_for("font_embedding", "font not embedded").violation_type)
      .to eq(:font_violation)
    expect(issue_for("viewbox_required", "missing viewBox").violation_type)
      .to eq(:viewbox_violation)
  end
end
