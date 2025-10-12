# frozen_string_literal: true

RSpec.shared_examples "Moxml::NodeSet" do
  describe Moxml::NodeSet do
    let(:context) { Moxml.new }
    let(:xml) do
      <<~XML
        <root>
          <child>First</child>
          <child>Second</child>
          <child>Third</child>
        </root>
      XML
    end
    let(:doc) { context.parse(xml) }
    let(:nodes) { doc.xpath("//child") }

    it "implements Enumerable" do
      expect(nodes).to be_a(Enumerable)
    end

    it "is a NodeSet" do
      expect(nodes).to be_a(described_class)
    end

    describe "enumeration" do
      it "iterates over nodes" do
        pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

        texts = []
        nodes.each { |node| texts << node.text }
        expect(texts).to eq(%w[First Second Third])
      end

      it "maps nodes" do
        pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

        texts = nodes.map(&:text)
        expect(texts).to eq(%w[First Second Third])
      end

      it "selects nodes" do
        pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

        selected = nodes.select { |node| node.text.include?("i") }
        expect(selected.size).to eq(2)
        expect(selected.map(&:text)).to eq(%w[First Third])
      end

      it "compares nodes" do
        pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

        expect(doc.xpath("//child")).to eq(doc.root.children)
      end
    end

    describe "access methods" do
      it "accesses by index" do
        pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

        expect(nodes[0].text).to eq("First")
        expect(nodes[1].text).to eq("Second")
        expect(nodes[-1].text).to eq("Third")
      end

      it "accesses by range" do
        pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

        subset = nodes[0..1]
        expect(subset).to be_a(described_class)
        expect(subset.size).to eq(2)
        expect(subset.map(&:text)).to eq(%w[First Second])
      end

      it "provides first and last" do
        pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

        expect(nodes.first.text).to eq("First")
        expect(nodes.last.text).to eq("Third")
      end
    end

    describe "modification methods" do
      it "removes all nodes" do
        nodes.remove
        expect(doc.xpath("//child")).to be_empty
      end

      it "preserves document structure after removal" do
        nodes.remove
        expect(doc.root).not_to be_nil
        expect(doc.root.name).to eq("root")
      end
    end

    describe "concatenation" do
      it "combines node sets" do
        pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

        other_doc = context.parse("<root><item>Fourth</item></root>")
        other_nodes = other_doc.xpath("//item")
        combined = nodes + other_nodes

        expect(combined).to be_a(described_class)
        expect(combined.size).to eq(4)
        expect(combined.map(&:text)).to eq(%w[First Second Third Fourth])
      end
    end
  end
end
