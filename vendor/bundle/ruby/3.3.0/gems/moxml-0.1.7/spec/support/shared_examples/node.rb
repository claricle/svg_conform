# frozen_string_literal: true

RSpec.shared_examples "Moxml::Node" do
  describe Moxml::Node do
    let(:context) { Moxml.new }
    let(:doc) { context.parse("<root><child>text</child></root>") }
    let(:root) { doc.root }
    let(:child) { root.children.first }

    describe "#document" do
      it "returns containing document" do
        expect(root.document).to eq(doc)
        expect(child.document).to eq(doc)
      end
    end

    describe "#parent" do
      it "returns parent node" do
        expect(child.parent).to eq(root)
        expect(root.parent).to be_a(Moxml::Document)
      end
    end

    describe "#children" do
      it "returns node set of children" do
        expect(root.children).to be_a(Moxml::NodeSet)
        expect(root.children.size).to eq(1)
      end
    end

    describe "sibling access" do
      let(:doc) { context.parse("<root><a/>text<b/></root>") }
      let(:first) { doc.root.children[0] }
      let(:middle) { doc.root.children[1] }
      let(:last) { doc.root.children[2] }

      it "navigates between siblings" do
        expect(first.next_sibling).to eq(middle)
        expect(middle.next_sibling).to eq(last)
        expect(last.previous_sibling).to eq(middle)
        expect(middle.previous_sibling).to eq(first)
      end
    end

    describe "node manipulation" do
      it "adds child" do
        new_child = doc.create_element("new")
        root.add_child(new_child)
        expect(root.children.last).to eq(new_child)
      end

      it "adds previous sibling" do
        new_node = doc.create_element("new")
        child.add_previous_sibling(new_node)
        expect(root.children.first).to eq(new_node)
      end

      it "adds next sibling" do
        new_node = doc.create_element("new")
        child.add_next_sibling(new_node)
        expect(root.children.last).to eq(new_node)
      end

      it "removes node" do
        child.remove
        expect(root.children).to be_empty
      end

      it "replaces node" do
        new_node = doc.create_element("new")
        child.replace(new_node)
        expect(root.children.first).to eq(new_node)
      end
    end

    describe "#to_xml" do
      let(:context) { Moxml.new }
      let(:doc) { context.parse("<root><child>text</child></root>") }

      it "uses native serialization" do
        expect(context.config.adapter).to receive(:serialize)
          .with(doc.native, hash_including(indent: 2))

        doc.to_xml(indent: 2)
      end

      it "passes through serialization options" do
        expect(context.config.adapter).to receive(:serialize)
          .with(doc.native, hash_including(encoding: "UTF-8", indent: 4))

        doc.to_xml(encoding: "UTF-8", indent: 4)
      end
    end

    describe "XPath support" do
      let(:doc) { context.parse("<root><a><b>1</b></a><a><b>2</b></a></root>") }

      it "finds nodes by xpath" do
        pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

        nodes = doc.xpath("//b")
        expect(nodes.size).to eq(2)
        expect(nodes.map(&:text)).to eq(%w[1 2])
      end

      it "finds first node by xpath" do
        pending "Ox doesn't have a native XPath" if context.config.adapter_name == :ox

        node = doc.at_xpath("//b")
        expect(node.text).to eq("1")
      end
    end
  end
end
