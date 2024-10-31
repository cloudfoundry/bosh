require 'json'

module IntegrationSupport
  module BlockHelpers
    def parse_blocks(source)
      Parser.new(source).data
    end

    class Parser
      def initialize(source)
        @source = source
      end

      def data
        begin
          parsed_data = JSON.parse(@source)
        rescue JSON::ParserError
          raise 'Be sure to pass `json: true` arg to bosh_runner.run'
        end
        parsed_data['Blocks']
      end
    end
  end
end

RSpec.configure do |config|
  config.include(IntegrationSupport::BlockHelpers)
end
