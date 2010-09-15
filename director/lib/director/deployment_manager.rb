module Bosh::Director

  class DeploymentManager

    def create_deployment(deployment_manifest)
      deployment_manifest_file = Tempfile.new("deployment_manifest")
      File.open(deployment_manifest_file.path, "w") do |f|
        buffer = ""
        f.write(buffer) until deployment_manifest.read(16384, buffer).nil?
      end

      task = Models::Task.new(:state => :queued, :timestamp => Time.now.to_i)
      task.create

      Resque.enqueue(Jobs::UpdateDeployment, task.id, deployment_manifest_file.path)

      task
    end

  end
end