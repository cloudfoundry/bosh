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
      # @param [String] index_or_id Job index or id
      # @return [Models::Instance]
      def find_by_name(deployment_name, job, index_or_id)
        # This is for backwards compatibility and can be removed when we move to referencing job by instance id only.
        if index_or_id.to_s =~ /^\d+$/
          InstanceLookup.new.by_attributes(deployment_name, job, index_or_id)
        else
          InstanceLookup.new.by_uuid(deployment_name, job, index_or_id)
        end
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
                "`#{instance.job}/#{instance.uuid} (#{instance.index})' doesn't reference a VM"
        end

        if vm.agent_id.nil?
          raise VmAgentIdMissing, "VM `#{vm.cid}' doesn't have an agent id"
        end

        AgentClient.with_vm(vm)
      end

      def fetch_logs(username, deployment_name, job, index_or_id, options = {})
        if deployment_name.nil? || job.nil? || index_or_id.nil?
          raise DirectorError,
                'deployment, job and index/id parameters are required'
        end

        # This is for backwards compatibility and can be removed when we move to referencing job by instance id only.
        if index_or_id.to_s =~ /^\d+$/
          instance = find_by_name(deployment_name, job, index_or_id)
        else
          instance = filter_by(uuid: index_or_id).first
        end

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
