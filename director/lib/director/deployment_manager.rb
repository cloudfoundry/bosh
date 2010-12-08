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

      task_status_file = File.join(Config.base_dir, "tasks", task.id.to_s)
      FileUtils.mkdir_p(File.dirname(task_status_file))
      logger = Logger.new(task_status_file)
      logger.level= Config.logger.level
      logger.info("Enqueuing task: #{task.id}")

      task.output = task_status_file
      task.save!

      Resque.enqueue(Jobs::UpdateDeployment, task.id, deployment_manifest_file.path)

      task
    end

  end
end