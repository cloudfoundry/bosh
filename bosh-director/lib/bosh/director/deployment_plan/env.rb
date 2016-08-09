module Bosh::Director
  module DeploymentPlan
    class Env
      include ValidationHelper

      # @return [Hash]
      attr_reader :env
      attr_reader :uninterpolated_env

      def initialize(env, uninterpolated_env)
        @env = env
        @uninterpolated_env = uninterpolated_env
      end

      def spec
        @env
      end

      def uninterpolated_spec
        @uninterpolated_env
      end
    end
  end
end
