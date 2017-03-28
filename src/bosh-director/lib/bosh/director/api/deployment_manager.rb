module Bosh::Director
  module Api
    class DeploymentManager
      include ApiHelper

      def initialize
        @deployment_lookup = DeploymentLookup.new
      end

      def find_by_name(name)
        @deployment_lookup.by_name(name)
      end

      def all_by_name_asc
        Bosh::Director::Models::Deployment.order_by(Sequel.asc(:name)).all
      end

      def create_deployment(username, manifest_text, cloud_config, runtime_config, deployment, options = {}, context_id = '')
        cloud_config_id = cloud_config.nil? ? nil : cloud_config.id
        runtime_config_id = runtime_config.nil? ? nil : runtime_config.id

        description = 'create deployment'
        description += ' (dry run)' if options['dry_run']

        JobQueue.new.enqueue(username, Jobs::UpdateDeployment, description, [manifest_text, cloud_config_id, runtime_config_id, options], deployment, context_id)
      end

      def delete_deployment(username, deployment, options = {}, context_id = '')
        JobQueue.new.enqueue(username, Jobs::DeleteDeployment, "delete deployment #{deployment.name}", [deployment.name, options], deployment, context_id)
      end

      def deployment_instances_with_vms(deployment)
        Models::Instance.where(deployment: deployment).exclude(active_vm_id: nil)
      end
    end
  end
end
