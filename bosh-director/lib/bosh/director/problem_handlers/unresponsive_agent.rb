module Bosh::Director
  module ProblemHandlers
    class UnresponsiveAgent < Base

      register_as :unresponsive_agent
      auto_resolution :ignore

      def initialize(instance_id, data)
        super
        @instance = Models::Instance.find(id: instance_id)

        unless @instance.vm_cid
          handler_error("VM '#{@instance.vm_cid}' is no longer in the database")
        end

        unless @instance.agent_id
          handler_error("VM '#{@instance.agent_id}' doesn't have an agent id")
        end
      end

      def description
        "#{@instance} (#{@instance.vm_cid}) is not responding"
      end

      resolution :ignore do
        plan { 'Skip for now' }
        action { }
      end

      resolution :reboot_vm do
        plan { 'Reboot VM' }
        action { validate; reboot_vm(@instance) }
      end

      resolution :recreate_vm do
        plan { "Recreate VM for '#{@instance}'" }
        action { validate; recreate_vm(@instance) }
      end

      resolution :delete_vm_reference do
        plan { 'Delete VM reference (forceful; may need to manually delete VM from the Cloud to avoid IP conflicts)' }
        action { validate; delete_vm_reference(@instance) }
      end

      private

      def agent_alive?
        agent_client(@instance.credentials, @instance.agent_id).ping
        true
      rescue Bosh::Director::RpcTimeout
        false
      end

      def validate
        if agent_alive?
          handler_error('Agent is responding now, skipping resolution')
        end
      end
    end
  end
end
