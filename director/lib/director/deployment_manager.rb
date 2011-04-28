module Bosh::Director

  class DeploymentManager
    include TaskHelper

    def create_deployment(user, deployment_manifest)
      deployment_manifest_file = File.join(Dir::tmpdir, "deployment-#{UUIDTools::UUID.random_create}")
      File.open(deployment_manifest_file, "w") do |f|
        buffer = ""
        f.write(buffer) until deployment_manifest.read(16384, buffer).nil?
      end

      task = create_task(user, "create deployment")
      Resque.enqueue(Jobs::UpdateDeployment, task.id, deployment_manifest_file)
      task
    end

    def delete_deployment(user, deployment)
      task = create_task(user, "delete deployment: #{deployment.name}")
      Resque.enqueue(Jobs::DeleteDeployment, task.id, deployment.name)
      task
    end

    def deployment_to_json(deployment)
      vms = deployment.vms.map do |vm|
        {
          "agent_id" => vm.agent_id,
          "cid"      => vm.cid
        }
      end

      result = {
        "manifest" => deployment.manifest,
        "vms"      => vms
      }

      Yajl::Encoder.encode(result)
    end

  end
end
