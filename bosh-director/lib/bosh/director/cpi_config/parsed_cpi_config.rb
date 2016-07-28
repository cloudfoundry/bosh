module Bosh::Director
  module CpiConfig
    class ParsedCpiConfig
      attr_reader :cpis

      def initialize(cpis)
        @cpis = cpis
      end

      def find_cpi_by_name(name)
        @cpis.select{|cpi|cpi.name == name}.first
      end
    end
  end
end
