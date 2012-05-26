# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class InstanceManager
      include TaskHelper

      def initialize
        @deployment_manager = DeploymentManager.new
      end

      # @param [Models::Deployment] deployment
      # @param [String] job
      # @param [String] index
      # @return [Models::Instance]
      def find_instance(deployment, job, index)
        filters = {
          :deployment_id => deployment.id,
          :job => job,
          :index => index
        }

        instance = Models::Instance.find(filters)
        if instance.nil?
          raise InstanceNotFound,
                "`#{deployment.name}/#{job}/#{index}' doesn't exist"
        end
        instance
      end

      def fetch_logs(user, deployment_name, job, index, options = {})
        if deployment_name.nil? || job.nil? || index.nil?
          raise DirectorError,
                "deployment, job and index parameters are required"
        end

        deployment = @deployment_manager.find_by_name(deployment_name)
        instance = find_instance(deployment, job, index)

        task = create_task(user, :fetch_logs, "fetch logs")
        Resque.enqueue(Jobs::FetchLogs, task.id, instance.id, options)
        task
      end

      def ssh(user, options)
        name = options["deployment_name"]
        command = options["command"]
        target = options["target"]

        deployment = @deployment_manager.find_by_name(name)
        task = create_task(user, :ssh, "ssh: #{command}:#{target}")

        Resque.enqueue(Jobs::Ssh, task.id, deployment.id, options)
        task
      end
    end
  end
end
