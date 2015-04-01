module Bosh::Director
  module Api
    class DeploymentManager
      include ApiHelper

      # Finds deployment by name
      # @param [String] name
      # @return [Models::Deployment] Deployment model
      # @raise [DeploymentNotFound]
      def find_by_name(name)
        DeploymentLookup.new.by_name(name)
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

      def deployment_to_json(deployment)
        result = {
          'manifest' => deployment.manifest,
        }

        Yajl::Encoder.encode(result)
      end

      def deployment_vms_to_json(deployment)
        vms = []
        filters = {:deployment_id => deployment.id}
        Models::Vm.eager(:instance).filter(filters).all.each do |vm|
          instance = vm.instance

          vms << {
            'agent_id' => vm.agent_id,
            'cid' => vm.cid,
            'job' => instance ? instance.job : nil,
            'index' => instance ? instance.index : nil
          }
        end

        Yajl::Encoder.encode(vms)
      end
    end
  end
end
