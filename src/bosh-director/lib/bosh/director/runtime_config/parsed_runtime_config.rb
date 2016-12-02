module Bosh::Director
  module RuntimeConfig
    class ParsedRuntimeConfig
      attr_reader :releases, :addons

      def initialize(releases, addons)
        @releases = releases
        @addons = addons
      end
    end
  end
end
