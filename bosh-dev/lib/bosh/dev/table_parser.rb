module Bosh
  module Dev
    class TableParser
      def initialize(table_string)
        @table_string = table_string
      end

      def to_a
        table = table_string.lines.grep(/^\| /)

        table = table.map { |line| line.split('|').map(&:strip).reject(&:empty?) }
        headers = table.shift || []
        headers.map! do |header|
          header.downcase.tr('/ ', '_').to_sym
        end
        table.reduce([]) do |rows, row|
          rows << Hash[headers.zip(row)]
        end
      end

      private

      attr_reader :table_string
    end
  end
end