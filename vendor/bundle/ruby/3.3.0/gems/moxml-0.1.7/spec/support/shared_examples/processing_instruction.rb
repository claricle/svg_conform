# frozen_string_literal: true

RSpec.shared_examples "Moxml::ProcessingInstruction" do
  let(:context) { Moxml.new }
  let(:doc) { context.create_document }
  let(:pi) { doc.create_processing_instruction("xml-stylesheet", 'href="style.xsl" type="text/xsl"') }

  it "identifies as processing instruction node" do
    expect(pi).to be_processing_instruction
  end

  describe "target manipulation" do
    it "gets target" do
      expect(pi.target).to eq("xml-stylesheet")
    end

    it "sets target" do
      pi.target = "new-target"
      expect(pi.target).to eq("new-target")
    end

    it "handles nil target" do
      pi.target = nil
      expect(pi.target).to eq("")
    end
  end

  describe "content manipulation" do
    it "gets content" do
      expect(pi.content).to eq('href="style.xsl" type="text/xsl"')
    end

    it "sets content" do
      pi.content = 'href="new.xsl"'
      expect(pi.content).to eq('href="new.xsl"')
    end

    it "handles nil content" do
      pi.content = nil
      expect(pi.content).to eq("")
    end
  end

  describe "serialization" do
    it "formats processing instruction" do
      expect(pi.to_xml.strip).to end_with('<?xml-stylesheet href="style.xsl" type="text/xsl"?>')
    end

    it "handles special characters" do
      pi.content = '< > & " \''
      expect(pi.to_xml).to include('< > & " \'')
    end
  end

  describe "node operations" do
    let(:element) { doc.create_element("test") }

    it "adds to element" do
      element.add_child(pi)
      expect(element.to_xml).to include("<?xml-stylesheet")
    end

    it "removes from element" do
      element.add_child(pi)
      pi.remove
      expect(element.children).to be_empty
    end

    it "replaces with another node" do
      element.add_child(pi)
      text = doc.create_text("replacement")
      pi.replace(text)
      expect(element.text).to eq("replacement")
    end
  end

  describe "common use cases" do
    it "creates stylesheet instruction" do
      pi = doc.create_processing_instruction("xml-stylesheet", 'type="text/xsl" href="style.xsl"')
      expect(pi.to_xml).to eq('<?xml-stylesheet type="text/xsl" href="style.xsl"?>')
    end

    it "creates PHP instruction" do
      pi = doc.create_processing_instruction("php", 'echo "Hello";')
      expect(pi.to_xml).to eq('<?php echo "Hello";?>')
    end
  end
end
