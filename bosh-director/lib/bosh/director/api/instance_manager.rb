module Bosh::Director
  module Api
    class InstanceManager
      # @param [Integer] instance_id Instance id
      # @return [Models::Instance] Instance
      # @raise [InstanceNotFound]
      def find_instance(instance_id)
        InstanceLookup.new.by_id(instance_id)
      end

      # @param [String] deployment_name Deployment name
      # @param [String] job Job name
      # @param [String] index Job index
      # @return [Models::Instance]
      def find_by_name(deployment_name, job, index)
        InstanceLookup.new.by_attributes(deployment_name, job, index)
      end

      # @param [Hash] filter Sequel-style DB record filter
      # @return [Array] List of instances that matched the filter
      # @raise [InstanceNotFound]
      def filter_by(filter)
        InstanceLookup.new.by_filter(filter)
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

        AgentClient.with_defaults(vm.agent_id)
      end

      def fetch_logs(username, deployment_name, job, index, options = {})
        if deployment_name.nil? || job.nil? || index.nil?
          raise DirectorError,
                'deployment, job and index parameters are required'
        end

        instance = find_by_name(deployment_name, job, index)

        JobQueue.new.enqueue(username, Jobs::FetchLogs, 'fetch logs', [instance.id, options])
      end

      def ssh(username, options)
        description = "ssh: #{options['command']}:#{options['target']}"
        deployment = DeploymentLookup.new.by_name(options['deployment_name'])

        JobQueue.new.enqueue(username, Jobs::Ssh, description, [deployment.id, options])
      end
    end
  end
end
