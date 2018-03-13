module Bosh::Director
  module CpiConfig
    class ParsedCpiConfig
      attr_reader :cpis

      def initialize(cpis)
        @cpis = cpis
      end

      def find_cpi_by_name(name)
        @cpis.find do |cpi|
          cpi.name == name ||
            cpi.migrated_from_names.include?(name)
        end
      end
    end
  end
end
