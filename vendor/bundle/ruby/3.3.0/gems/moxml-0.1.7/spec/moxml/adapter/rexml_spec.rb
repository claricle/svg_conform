# frozen_string_literal: true

require "rexml"
require "moxml/adapter/rexml"

RSpec.describe Moxml::Adapter::Rexml do
  around do |example|
    Moxml.with_config(:rexml, true, "UTF-8") do
      example.run
    end
  end

  it_behaves_like "xml adapter"
end
