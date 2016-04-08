module Bosh::Director
  module DeploymentPlan
    class Env
      include ValidationHelper

      # @return [Hash]
      attr_reader :env

      def initialize(spec)
        @env = spec
      end

      def spec
        @env
      end
    end
  end
end
