module Bosh::Director
  module CpiConfig
    class ParsedCpiConfig
      attr_reader :cpis

      def initialize(cpis)
        @cpis = cpis
      end
    end
  end
end
