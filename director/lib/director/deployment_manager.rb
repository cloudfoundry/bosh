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

    def delete_deployment(user, deployment)
      task = create_task(user, "delete deployment: #{deployment.name}")
      Resque.enqueue(Jobs::DeleteDeployment, task.id, deployment.name)
      task
    end

  end
end
