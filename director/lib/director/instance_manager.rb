module Bosh::Director

  class InstanceManager
    include TaskHelper

    def fetch_logs(user, deployment_name, job, index, options = {})
      if deployment_name.nil? || job.nil? || index.nil?
        raise InvalidRequest.new("deployment, job and index parameters are required")
      end

      deployment = Models::Deployment.find(:name => deployment_name)
      raise DeploymentNotFound.new(deployment_name) if deployment.nil?

      instance = Models::Instance.find(:deployment_id => deployment.id, :job => job, :index => index)
      raise InstanceNotFound.new("#{job}/#{index}") if instance.nil?

      task = create_task(user, "fetch logs")
      Resque.enqueue(Jobs::FetchLogs, task.id, instance.id, options)
      task
    end

    def ssh(user, options)
      task = create_task(user, "ssh: #{options["command"]}:#{options["target"]}")

      deployment = Models::Deployment.find(:name => options["deployment_name"])
      raise DeploymentNotFound.new(deployment_name) if deployment.nil?

      Resque.enqueue(Jobs::Ssh, task.id, deployment.id, options)
      task
    end
  end

end
