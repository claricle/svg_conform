# frozen_string_literal: true

require "benchmark"
require "benchmark/ips"

RSpec.shared_examples "Performance Examples" do
  let(:context) { Moxml.new }

  let(:large_xml) do
    xml = "<root>\n"
    1000.times do |i|
      xml += "<item id='#{i}'><name>Test #{i}</name><value>#{i}</value></item>\n"
    end
    xml += "</root>"
    xml
  end

  it "measures parsing performance" do
    doc = nil

    report = Benchmark.ips do |x|
      x.config(time: 5, warmup: 2)

      x.report("Parser") do
        doc = context.parse(large_xml)
      end

      x.report("Serializer") do
        _ = doc.to_xml
      end

      x.compare!
    end

    # first - parser, second - serializer
    thresholds = {
      nokogiri: [18, 1200],
      oga: [12, 110],
      rexml: [0, 60],
      ox: [2, 2000]
    }

    report.entries.each_with_index do |entry, index|
      puts "#{entry.label} performance: #{entry.ips.round(2)} ips"
      threshold = thresholds[context.config.adapter_name][index]
      message = "#{entry.label} performance below threshold: " \
                "got #{entry.ips.round(2)} ips, expected >= #{threshold} ips"
      expect(entry.ips).to be >= threshold, message
    end
  end
end
