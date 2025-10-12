# frozen_string_literal: true

RSpec.shared_examples "Thread Safety Examples" do
  describe "Thread-safe processing" do
    let(:processor_class) do
      Class.new do
        def initialize
          @mutex = Mutex.new
          @context = Moxml.new
        end

        def process(xml)
          @mutex.synchronize do
            doc = @context.parse(xml)
            yield doc if block_given?
            doc.to_xml
          end
        end
      end
    end

    it "handles concurrent processing" do
      pending "Ox doesn't have a native XPath" if Moxml.new.config.adapter_name == :ox

      processor = processor_class.new
      threads = []
      results = Queue.new

      10.times do |i|
        threads << Thread.new do
          xml = "<root><id>#{i}</id></root>"
          result = processor.process(xml) do |doc|
            # Simulate some work
            sleep(rand * 0.1)
            doc.at_xpath("//id").text
          end
          results << result
        end
      end

      threads.each(&:join)
      expect(results.size).to eq(10)
    end
  end
end
