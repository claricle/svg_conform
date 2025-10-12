# frozen_string_literal: true

require "nokogiri"
require "moxml/adapter/nokogiri"

RSpec.describe Moxml::Adapter::Nokogiri do
  around do |example|
    Moxml.with_config(:nokogiri, true, "UTF-8") do
      example.run
    end
  end

  it_behaves_like "xml adapter"
end
