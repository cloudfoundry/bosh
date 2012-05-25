# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class InstanceManager
      include TaskHelper

      def fetch_logs(user, deployment_name, job, index, options = {})
        if deployment_name.nil? || job.nil? || index.nil?
          raise InvalidRequest.new(
                    "deployment, job and index parameters are required")
        end

        deployment = Models::Deployment.find(:name => deployment_name)
        raise DeploymentNotFound.new(deployment_name) if deployment.nil?

        filters = {:deployment_id => deployment.id, :job => job,
                   :index => index}
        instance = Models::Instance.find(filters)
        raise InstanceNotFound.new("#{job}/#{index}") if instance.nil?

        task = create_task(user, :fetch_logs, "fetch logs")
        Resque.enqueue(Jobs::FetchLogs, task.id, instance.id, options)
        task
      end

      def ssh(user, options)
        task_name = "ssh: #{options["command"]}:#{options["target"]}"
        task = create_task(user, :ssh, task_name)

        filters = {:name => options["deployment_name"]}
        deployment = Models::Deployment.find(filters)
        raise DeploymentNotFound.new(deployment_name) if deployment.nil?

        Resque.enqueue(Jobs::Ssh, task.id, deployment.id, options)
        task
      end
    end
  end
end
