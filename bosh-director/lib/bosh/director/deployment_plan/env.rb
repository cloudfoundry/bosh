module Bosh::Director
  module DeploymentPlan
    class Env
      include ValidationHelper

      # @return [Hash]
      attr_reader :env

      def initialize(env)
        @env = env
      end

      def spec
        @env
      end
    end
  end
end
