module Bosh::Director

  class DeploymentManager
    include TaskHelper

    def create_deployment(deployment_manifest)
      deployment_manifest_file = File.join(Dir::tmpdir, "deployment-#{UUIDTools::UUID.random_create}")
      File.open(deployment_manifest_file, "w") do |f|
        buffer = ""
        f.write(buffer) until deployment_manifest.read(16384, buffer).nil?
      end

      task = create_task("create deployment")
      Resque.enqueue(Jobs::UpdateDeployment, task.id, deployment_manifest_file)
      task
    end

    def delete_deployment(deployment)
      task = create_task("delete deployment: #{deployment.name}")
      Resque.enqueue(Jobs::DeleteDeployment, task.id, deployment.name)
      task
    end

  end
end