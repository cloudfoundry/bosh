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
        with_vm_cid = if @instance.vm_cid
          " with cloud ID '#{@instance.vm_cid}'"
        else
          ''
        end
        "VM for '#{@instance}'#{with_vm_cid} is not responding."
      end

      def instance_problem?
        true
      end

      resolution :ignore do
        plan { 'Skip for now' }
        action { }
      end

      resolution :reboot_vm do
        plan { 'Reboot VM' }
        action { validate; reboot_vm(@instance) }
      end

      resolution :recreate_vm_without_wait do
        plan { 'Recreate VM without waiting for processes to start' }
        action { validate; recreate_vm_without_wait(@instance) }
      end

      resolution :recreate_vm do
        plan { 'Recreate VM and wait for processes to start' }
        action { validate; recreate_vm(@instance) }
      end

      resolution :delete_vm do
        plan { 'Delete VM' }
        action { validate; delete_vm_from_cloud(@instance) }
      end

      resolution :delete_vm_reference do
        plan { 'Delete VM reference (forceful; may need to manually delete VM from the Cloud to avoid IP conflicts)' }
        action { validate; delete_vm_reference(@instance) }
      end

      private

      def agent_alive?
        agent_client(@instance.agent_id, @instance.name).ping
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
