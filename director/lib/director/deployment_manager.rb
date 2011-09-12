module Bosh::Director

  class DeploymentManager
    include TaskHelper

    def create_deployment(user, deployment_manifest, options = {})
      deployment_manifest_file = File.join(Dir::tmpdir, "deployment-#{UUIDTools::UUID.random_create}")
      File.open(deployment_manifest_file, "w") do |f|
        buffer = ""
        f.write(buffer) until deployment_manifest.read(16384, buffer).nil?
      end

      task = create_task(user, "create deployment")
      Resque.enqueue(Jobs::UpdateDeployment, task.id, deployment_manifest_file, options)
      task
    end

    def delete_deployment(user, deployment, options = {})
      task = create_task(user, "delete deployment: #{deployment.name}")
      Resque.enqueue(Jobs::DeleteDeployment, task.id, deployment.name, options)
      task
    end

    def deployment_to_json(deployment)
      result = {
        "manifest" => deployment.manifest,
      }

      Yajl::Encoder.encode(result)
    end

    def deployment_vms_to_json(deployment)
      vms = [ ]

      deployment.vms.each do |vm|
        instance = vm.instance

        vms << {
          "agent_id" => vm.agent_id,
          "job"      => instance ? instance.job : nil,
          "index"    => instance ? instance.index : nil
        }
      end

      Yajl::Encoder.encode(vms)
    end

  end
end
