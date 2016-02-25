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
        Bosh::Director::Models::Deployment.order_by(:name.asc).all
      end

      def create_deployment(username, deployment_manifest, cloud_config, options = {})
        random_name = "deployment-#{SecureRandom.uuid}"
        deployment_manifest_dir = Dir::tmpdir
        deployment_manifest_file = File.join(deployment_manifest_dir, random_name)
        unless check_available_disk_space(deployment_manifest_dir, deployment_manifest.size)
          raise NotEnoughDiskSpace, 'Uploading deployment manifest failed. ' +
            "Insufficient space on BOSH director in #{deployment_manifest_dir}"
        end

        write_file(deployment_manifest_file, deployment_manifest)

        cloud_config_id = cloud_config.nil? ? nil : cloud_config.id
        JobQueue.new.enqueue(username, Jobs::UpdateDeployment, 'create deployment', [deployment_manifest_file, cloud_config_id, options])
      end

      def delete_deployment(username, deployment, options = {})
        JobQueue.new.enqueue(username, Jobs::DeleteDeployment, "delete deployment #{deployment.name}", [deployment.name, options])
      end

      def deployment_instances_with_vms(deployment)
        Models::Instance.where(deployment: deployment).exclude(vm_cid: nil)
      end
    end
  end
end
