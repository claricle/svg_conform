# frozen_string_literal: true

# spec/moxml_spec.rb
RSpec.describe Moxml do
  it "has a version number" do
    expect(Moxml::VERSION).not_to be_nil
  end

  describe ".new" do
    it "creates a new context" do
      expect(Moxml.new).to be_a(Moxml::Context)
    end

    it "accepts adapter specification" do
      context = Moxml.new(:nokogiri)
      expect(context.config.adapter_name).to eq(:nokogiri)
    end

    it "raises error for invalid adapter" do
      expect { Moxml.new(:invalid) }.to raise_error(ArgumentError)
    end
  end

  describe ".configure" do
    around do |example|
      # preserve the original config because it may be changed in examples
      Moxml.with_config { example.run }
    end

    it "sets default values without a block" do
      Moxml.configure

      context = Moxml.new
      expect(context.config.adapter_name).to eq(:nokogiri)
    end

    it "uses configured options from the block" do
      Moxml.configure do |config|
        config.default_adapter = :oga
        config.strict_parsing = false
        config.default_encoding = "US-ASCII"
      end

      context = Moxml.new
      expect(context.config.adapter_name).to eq(:oga)
      expect(context.config.strict_parsing).to eq(false)
      expect(context.config.default_encoding).to eq("US-ASCII")
    end
  end
end
