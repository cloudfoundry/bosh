require 'dogapi'
require 'bosh/dev/emitable_example'

module Bosh::Dev
  class DataDogReporter
    def initialize(data_dog_client = Dogapi::Client.new(ENV.fetch('BAT_DATADOG_API_KEY')))
      @data_dog_client = data_dog_client
    end

    def report_on(example)
      emitable_example = EmitableExample.new(example)
      puts "Emiting: #{emitable_example.to_a.inspect}"
      data_dog_client.emit_point(*emitable_example)
    end

    private

    attr_reader :data_dog_client
  end
end
