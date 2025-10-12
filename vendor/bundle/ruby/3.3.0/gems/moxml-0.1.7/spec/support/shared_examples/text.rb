# frozen_string_literal: true

RSpec.shared_examples "Moxml::Text" do
  let(:context) { Moxml.new }
  let(:doc) { context.create_document }
  let(:text) { doc.create_text("content") }

  it "identifies as text node" do
    expect(text).to be_text
  end

  describe "content manipulation" do
    it "gets content" do
      expect(text.content).to eq("content")
    end

    it "sets content" do
      text.content = "new content"
      expect(text.content).to eq("new content")
    end

    it "handles nil content" do
      text.content = nil
      expect(text.content).to eq("")
    end

    it "converts non-string content" do
      text.content = 123
      expect(text.content).to eq("123")
    end
  end

  describe "special characters" do
    it "encodes basic XML entities" do
      text.content = "< > & \" '"
      doc.add_child(text)
      expect(doc.to_xml.strip).to end_with("&lt; &gt; &amp; \" '")
    end

    it "preserves whitespace" do
      text.content = "  spaced  content\n\t"
      expect(text.content).to eq("  spaced  content\n\t")
    end
  end

  describe "node operations" do
    let(:element) { doc.create_element("test") }

    it "adds to element" do
      element.add_child(text)
      expect(element.text).to eq("content")
    end

    it "removes from element" do
      element.add_child(text)
      text.remove
      expect(element.text).to eq("")
    end

    it "replaces with another node" do
      element.add_child(text)
      new_text = doc.create_text("replacement")
      text.replace(new_text)
      expect(element.text).to eq("replacement")
    end
  end
end
