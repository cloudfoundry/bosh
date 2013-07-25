# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class InstanceManager
      def initialize
        @deployment_manager = DeploymentManager.new
      end

      # @param [Integer] instance_id Instance id
      # @return [Models::Instance] Instance
      # @raise [InstanceNotFound]
      def find_instance(instance_id)
        instance = Models::Instance[instance_id]
        if instance.nil?
          raise InstanceNotFound, "Instance #{instance_id} doesn't exist"
        end
        instance
      end

      # @param [String] deployment_name Deployment name
      # @param [String] job Job name
      # @param [String] index Job index
      # @return [Models::Instance]
      def find_by_name(deployment_name, job, index)
        deployment = @deployment_manager.find_by_name(deployment_name)

        filter = {
          :deployment_id => deployment.id,
          :job => job,
          :index => index
        }

        instance = Models::Instance.find(filter)
        if instance.nil?
          raise InstanceNotFound,
                "`#{deployment_name}/#{job}/#{index}' doesn't exist"
        end
        instance
      end

      # @param [Hash] filter Sequel-style DB record filter
      # @return [Array] List of instances that matched the filter
      # @raise [InstanceNotFound]
      def filter_by(filter)
        instances = Models::Instance.filter(filter).all
        if instances.empty?
          raise InstanceNotFound, "No instances matched #{filter.inspect}"
        end
        instances
      end

      # @param [Models::Instance] instance Instance
      # @return [AgentClient] Agent client to talk to instance
      def agent_client_for(instance)
        vm = instance.vm
        if vm.nil?
          raise InstanceVmMissing,
                "`#{instance.job}/#{instance.index}' doesn't reference a VM"
        end

        if vm.agent_id.nil?
          raise VmAgentIdMissing, "VM `#{vm.cid}' doesn't have an agent id"
        end

        AgentClient.new(vm.agent_id)
      end

      def fetch_logs(user, deployment_name, job, index, options = {})
        if deployment_name.nil? || job.nil? || index.nil?
          raise DirectorError,
                "deployment, job and index parameters are required"
        end

        instance = find_by_name(deployment_name, job, index)

        JobQueue.new.enqueue(user, Jobs::FetchLogs, 'fetch logs', [instance.id, options])
      end

      def ssh(user, options)
        description = "ssh: #{options['command']}:#{options['target']}"
        deployment = @deployment_manager.find_by_name(options['deployment_name'])

        JobQueue.new.enqueue(user, Jobs::Ssh, description, [deployment.id, options])
      end
    end
  end
end
