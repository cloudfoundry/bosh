module Bosh::Director
  module DeploymentPlan
    class LinkInfo
      def initialize(deployment_name, link_spec = {})
        @deployment_name=deployment_name
        @link_spec=link_spec
      end

      def spec
        result = Bosh::Common::DeepCopy.copy(@link_spec)
        result['deployment_name'] = @deployment_name
        result
      end
    end
  end
end