module Bosh::Director
  module Api
    class InstanceManager
      # @param [Integer] instance_id Instance id
      # @return [Models::Instance] Instance
      # @raise [InstanceNotFound]
      def find_instance(instance_id)
        InstanceLookup.new.by_id(instance_id)
      end

      # @param [Models::Deployment] deployment
      # @param [String] job Job name
      # @param [String] index_or_id Job index or id
      # @return [Models::Instance]
      def find_by_name(deployment, job, index_or_id)
        # This is for backwards compatibility and can be removed when we move to referencing job by instance id only.
        if index_or_id.to_s =~ /^\d+$/
          InstanceLookup.new.by_attributes(deployment, job, index_or_id)
        else
          InstanceLookup.new.by_uuid(deployment, job, index_or_id)
        end
      end

      def find_instances_by_deployment(deployment)
        InstanceLookup.new.by_deployment(deployment)
      end

      # @param [Models::Deployment] deployment
      # @param [Hash] filter Sequel-style DB record filter
      # @return [Array] List of instances that matched the filter
      # @raise [InstanceNotFound]
      def filter_by(deployment, filter)
        InstanceLookup.new.by_filter(filter.merge(deployment_id: deployment.id))
      end

      # @param [Models::Instance] instance Instance
      # @return [AgentClient] Agent client to talk to instance
      def agent_client_for(instance)
        unless instance.active_vm
          raise InstanceVmMissing,
                "'#{instance}' doesn't reference a VM"
        end

        unless instance.active_vm.agent_id
          raise VmAgentIdMissing, "VM '#{instance.active_vm.cid}' doesn't have an agent id"
        end

        AgentClient.with_vm_credentials_and_agent_id(instance.credentials, instance.agent_id)
      end

      def fetch_logs(username, deployment, job, index_or_id, options = {})
        if deployment.nil?
          raise DirectorError,
                'deployment parameter is required'
        end

        instance_ids = []
        if !index_or_id.nil?
          # This is for backwards compatibility and can be removed when we move to referencing job by instance id only.
          if index_or_id.to_s =~ /^\d+$/
            instance = find_by_name(deployment, job, index_or_id)
          else
            instance = filter_by(deployment, uuid: index_or_id).first
          end
          instance_ids << instance.id
        elsif job.nil?
          instance_ids = find_instances_by_deployment(deployment).map(&:id)
        else
          instance_ids = filter_by(deployment, job: job).map(&:id)
        end

        JobQueue.new.enqueue(username, Jobs::FetchLogs, 'fetch logs', [instance_ids, options], deployment)
      end

      def fetch_instances(username, deployment, format)
        JobQueue.new.enqueue(username, Jobs::VmState, 'retrieve vm-stats', [deployment.id, format, true], deployment)
      end

      def fetch_instances_with_vm(username, deployment, format)
        JobQueue.new.enqueue(username, Jobs::VmState, 'retrieve vm-stats', [deployment.id, format], deployment)
      end

      def ssh(username, deployment, options)
        description = "ssh: #{options['command']}:#{options['target']}"

        JobQueue.new.enqueue(username, Jobs::Ssh, description, [deployment.id, options], deployment)
      end
    end
  end
end
