# frozen_string_literal: true

RSpec.shared_examples "Moxml::Comment" do
  let(:context) { Moxml.new }
  let(:doc) { context.create_document }
  let(:comment) { doc.create_comment("test comment") }

  it "identifies as comment node" do
    expect(comment).to be_comment
  end

  describe "content manipulation" do
    it "gets content" do
      expect(comment.content).to eq("test comment")
    end

    it "sets content" do
      comment.content = "new comment"
      expect(comment.content).to eq("new comment")
    end

    it "handles nil content" do
      comment.content = nil
      expect(comment.content).to eq("")
    end
  end

  describe "serialization" do
    it "wraps content in comment markers" do
      expect(comment.to_xml).to eq("<!--test comment-->")
    end

    it "raises an error on double hyphens" do
      expect { comment.content = "test -- comment" }
        .to raise_error(Moxml::ValidationError, "XML comment cannot contain double hyphens (--)")
    end

    it "handles special characters" do
      comment.content = "< > & \" '"
      expect(comment.to_xml).to eq("<!--< > & \" '-->")
    end
  end

  describe "node operations" do
    let(:element) { doc.create_element("test") }

    it "adds to element" do
      element.add_child(comment)
      expect(element.to_xml).to include("<!--test comment-->")
    end

    it "removes from element" do
      element.add_child(comment)
      comment.remove
      expect(element.children).to be_empty
    end

    it "replaces with another node" do
      element.add_child(comment)
      text = doc.create_text("replacement")
      comment.replace(text)
      expect(element.text).to eq("replacement")
    end
  end
end
