# frozen_string_literal: true

RSpec.describe "Test all shared examples" do
  all_shared_examples = [
    "Moxml::Node",
    "Moxml::Namespace",
    "Moxml::Attribute",
    "Moxml::NodeSet",
    "Moxml::Element",
    "Moxml::Cdata",
    "Moxml::Comment",
    "Moxml::Text",
    "Moxml::ProcessingInstruction",
    "Moxml::Declaration",
    "Moxml::Doctype",
    "Moxml::Document",
    "Moxml::Context",
    "Moxml::Builder",
    "Moxml::DocumentBuilder",
    "Moxml Integration",
    "Moxml Edge Cases",
    "Attribute Examples",
    "Basic Usage Examples",
    "Namespace Examples",
    "README Examples",
    "XPath Examples",
    "Memory Usage Examples",
    "Thread Safety Examples",
    "Performance Examples"
  ]

  Moxml::Adapter::AVALIABLE_ADAPTERS.each do |adapter_name|
    context "with #{adapter_name}" do
      around do |example|
        Moxml.with_config(adapter_name) do
          example.run
        end
      end

      all_shared_examples.each do |shared_example_name|
        it_behaves_like shared_example_name
      end
    end
  end
end
