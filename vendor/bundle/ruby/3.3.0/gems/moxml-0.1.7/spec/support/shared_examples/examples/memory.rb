# frozen_string_literal: true

require "get_process_mem"
require "tempfile"

RSpec.shared_examples "Memory Usage Examples" do
  let(:context) { Moxml.new }

  describe "Memory efficient processing" do
    it "processes large documents efficiently", skip: "Oga fails this test" do
      # Create large document
      doc = context.create_document
      root = doc.create_element("root")
      doc.add_child(root)

      1000.times do |i|
        node = doc.create_element("large-node")
        node.add_child(doc.create_text("Content #{i}"))
        root.add_child(node)
      end

      # Process and remove nodes
      memory_before = GetProcessMem.new.bytes
      doc.xpath("//large-node").each(&:remove)
      GC.start
      memory_after = GetProcessMem.new.bytes

      expect(memory_after).to be <= memory_before
      expect(doc.xpath("//large-node")).to be_empty
    end

    it "handles deeply nested nodes", skip: "Very flaky tests" do
      doc = context.create_document
      parent = doc

      1000.times do |i|
        node = doc.create_element("el_#{i}")
        node.add_child(doc.create_text("Content #{i}"))
        parent.add_child(node)
        parent = node
      end

      # Process and remove nodes
      memory_before = GetProcessMem.new.bytes
      doc = nil
      GC.start # Oga fails without it
      memory_after = GetProcessMem.new.bytes

      expect(memory_after).to be <= memory_before
      expect(doc).to be_nil
    end

    it "handles streaming processing" do
      pending "Ox has a load_file method, but nothing about a stream" if context.config.adapter_name == :ox
      # Process file
      doc = nil
      File.open("spec/fixtures/small.xml") do |f|
        doc = context.parse(f)
        expect(doc.at_xpath("//item").text).to eq("data")
        doc = nil
      end
      GC.start

      expect(doc).to be_nil
    end
  end
end
