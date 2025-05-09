require 'json'

module IntegrationSupport
  module TableHelpers
    def table(source)
      Parser.new(source).data
    end

    class Parser
      def initialize(source)
        @source = source
      end

      def data
        begin
          table_data = JSON.parse(@source)
        rescue JSON::ParserError
          raise 'Be sure to pass `json: true` arg to bosh_runner.run'
        end

        table_entries = []

        table_data['Tables'].each do |table|
          table_entries += table['Rows'] || []
        end

        table_entries
      end
    end
  end
end

RSpec.configure do |config|
  config.include(IntegrationSupport::TableHelpers)
end
