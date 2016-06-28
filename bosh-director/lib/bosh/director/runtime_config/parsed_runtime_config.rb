module Bosh::Director
  module DeploymentPlan
    class ParsedRuntimeConfig
      attr_reader :releases
      attr_reader :addons
      attr_reader :includes

      def initialize(releases, addons, includes)
        @releases = releases
        @addons = addons
        @includes = includes
      end
    end
  end
end