# frozen_string_literal: true

# spec/moxml/config_spec.rb
RSpec.describe Moxml::Config do
  subject(:config) { described_class.new }

  describe "#initialize" do
    it "sets default values" do
      expect(config.adapter_name).to eq(:nokogiri)
      expect(config.strict_parsing).to be true
      expect(config.default_encoding).to eq("UTF-8")
      expect(config.default_indent).to eq(2)
      expect(config.entity_encoding).to eq(:basic)
    end
  end

  describe "#adapter=" do
    it "sets valid adapter" do
      config.adapter = :ox
      expect(config.adapter_name).to eq(:ox)
    end

    it "raises error for invalid adapter" do
      expect { config.adapter = :invalid }.to raise_error(ArgumentError)
    end

    it "requires adapter gem" do
      expect { config.adapter = :oga }.not_to raise_error

      expect(defined?(::Oga)).to be_truthy
    end

    it "handles missing gems" do
      allow(Moxml::Adapter).to receive(:require).and_raise(LoadError)
      expect { config.adapter = :nokogiri }.to raise_error(LoadError)
    end
  end

  describe "#adapter" do
    it "returns nokogiri adapter by default" do
      expect(config.adapter).to eq(Moxml::Adapter::Nokogiri)
    end

    it "caches adapter instance" do
      adapter = config.adapter
      expect(config.adapter.object_id).to eq(adapter.object_id)
    end

    it "resets cached adapter when changing adapter type" do
      original = config.adapter
      config.adapter = :ox
      expect(config.adapter).not_to eq(original)
    end
  end
end
