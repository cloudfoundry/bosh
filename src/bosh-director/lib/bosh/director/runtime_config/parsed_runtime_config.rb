module Bosh::Director
  module RuntimeConfig
    class ParsedRuntimeConfig
      attr_reader :releases, :addons, :variables

      def initialize(releases, addons, variables)
        @releases = releases
        @addons = addons
        @variables = variables
      end
    end
  end
end
