# frozen_string_literal: true

RSpec.shared_examples "Moxml::Declaration" do
  let(:context) { Moxml.new }
  let(:doc) { context.create_document }
  let(:declaration) { doc.create_declaration("1.0", "UTF-8", "yes") }

  it "identifies as declaration node" do
    expect(declaration).to be_declaration
  end

  describe "version handling" do
    it "gets version" do
      expect(declaration.version).to eq("1.0")
    end

    it "sets version" do
      declaration.version = "1.1"
      expect(declaration.version).to eq("1.1")
    end

    it "validates version" do
      expect { declaration.version = "2.0" }
        .to raise_error(Moxml::ValidationError, "Invalid XML version: 2.0")
    end
  end

  describe "encoding handling" do
    it "gets encoding" do
      expect(declaration.encoding).to eq("UTF-8")
    end

    it "sets encoding" do
      declaration.encoding = "ISO-8859-1"
      expect(declaration.encoding).to eq("ISO-8859-1")
    end

    it "normalizes encoding" do
      pending("Rexml Encoding upcases the string") if Moxml.new.config.adapter.name.include?("Rexml")
      declaration.encoding = "utf-8"
      expect(declaration.encoding).to eq("utf-8")
    end
  end

  describe "standalone handling" do
    it "gets standalone" do
      expect(declaration.standalone).to eq("yes")
    end

    it "sets standalone" do
      declaration.standalone = "no"
      expect(declaration.standalone).to eq("no")
    end

    it "validates standalone value" do
      expect { declaration.standalone = "maybe" }
        .to raise_error(Moxml::ValidationError, "Invalid standalone value: maybe")
    end

    it "allows nil standalone" do
      declaration.standalone = nil
      expect(declaration.standalone).to be_nil
    end
  end

  describe "serialization" do
    it "formats complete declaration" do
      doc.add_child(declaration)
      expect(doc.to_xml.strip).to end_with('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    end

    it "formats minimal declaration with empty encoding" do
      decl = doc.create_declaration("1.0", nil)
      if context.config.adapter_name == :rexml
        # REXML sets a default encoding when a declaration is added to the document
        expect(decl.to_xml.strip).to eq('<?xml version="1.0"?>')
      else
        # Ox cannot serialize standalone declaration
        doc.add_child(decl)
        expect(doc.to_xml.strip).to end_with('<?xml version="1.0"?>')
      end
    end

    it "formats declaration with encoding only" do
      decl = doc.create_declaration("1.0", "UTF-8")
      doc.add_child(decl)
      expect(doc.to_xml.strip).to end_with('<?xml version="1.0" encoding="UTF-8"?>')
    end
  end

  describe "node operations" do
    it "adds to document" do
      doc.add_child(declaration)
      expect(doc.to_xml).to start_with("<?xml")
    end

    it "removes from document" do
      if Moxml.new.config.adapter.name.match?(/Nokogiri|Rexml|Ox/)
        pending("The document contains a default declaration")
      end
      doc.add_child(declaration)
      declaration.remove
      expect(doc.to_xml).not_to include("<?xml")
    end
  end
end
