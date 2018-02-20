module Bosh::Director
  module DeploymentPlan
    class DeploymentValidator
      def initialize
        @links_manager = Bosh::Director::Links::LinksManagerFactory.create.create_manager
      end

      def validate(deployment)
        if deployment.stemcells.empty? && deployment.resource_pools.empty?
          raise DeploymentInvalidResourceSpecification, "'stemcells' or 'resource_pools' need to be specified"
        elsif deployment.stemcells.any? && deployment.resource_pools.any?
          raise DeploymentInvalidResourceSpecification, "'resource_pools' cannot be specified along with 'stemcells'"
        end

        @links_manager.resolve_deployment_links(deployment.model, {dry_run: true, global_use_dns_entry: deployment.use_dns_addresses?})
      end
    end
  end
end
