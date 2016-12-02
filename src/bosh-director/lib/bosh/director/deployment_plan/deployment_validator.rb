module Bosh::Director
  module DeploymentPlan
    class DeploymentValidator
      def validate(deployment)
        if deployment.vm_types.any? || deployment.stemcells.any?
          if deployment.resource_pools.any?
            raise DeploymentInvalidResourceSpecification, "'resource_pools' cannot be specified along with 'stemcells' and/or 'vm_types'"
          elsif deployment.stemcells.empty?
            raise DeploymentInvalidResourceSpecification, "Both 'stemcells' and 'vm_types' need to be specified: 'stemcells' is missing"
          elsif deployment.vm_types.empty?
            raise DeploymentInvalidResourceSpecification, "Both 'stemcells' and 'vm_types' need to be specified: 'vm_types' is missing"
          end
        end
      end
    end
  end
end
