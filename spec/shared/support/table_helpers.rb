require 'csv'

module Support
  module TableHelpers
    def table(source)
      Parser.new(source).data
    end

    class Parser
      def initialize(source)
        @source = source
      end

      def data
        table = parsed.dup
        head = table.shift
        table.map { |row| Hash[head.zip(row)] }
      end

      private

      def parsed
        @parsed ||= parse(@source).map { |row| row.map(&:strip) }
      end

      def clean(content)
        content.strip.gsub(/^[^|].*\n?/, '')
      end

      def parse(content)
        CSV.parse(clean(content), { col_sep: "|" }).map(&:compact)
      end
    end
  end
end

RSpec.configure do |config|
  config.include(Support::TableHelpers)
end
