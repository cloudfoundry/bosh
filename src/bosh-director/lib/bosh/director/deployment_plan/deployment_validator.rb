module Bosh::Director
  module DeploymentPlan
    class DeploymentValidator
      def validate(deployment)
        if deployment.stemcells.empty? && deployment.resource_pools.empty?
          raise DeploymentInvalidResourceSpecification, "'stemcells' or 'resource_pools' need to be specified"
        elsif deployment.stemcells.any? && deployment.resource_pools.any?
          raise DeploymentInvalidResourceSpecification, "'resource_pools' cannot be specified along with 'stemcells'"
        end
      end
    end
  end
end
