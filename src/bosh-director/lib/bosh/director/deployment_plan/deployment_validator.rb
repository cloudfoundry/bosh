module Bosh::Director
  module DeploymentPlan
    class DeploymentValidator
      def validate(deployment)
        raise DeploymentInvalidResourceSpecification, "'stemcells' needs to be specified" if deployment.stemcells.empty?

        if deployment.is_deploy?
          @links_manager = Bosh::Director::Links::LinksManager.new(deployment.model.links_serial_id)
          @links_manager.resolve_deployment_links(deployment.model, {dry_run: true, global_use_dns_entry: deployment.use_dns_addresses?})
        end
      end
    end
  end
end
