module Bosh::Director
  module ProblemHandlers
    class UnresponsiveAgent < Base

      register_as :unresponsive_agent
      auto_resolution :ignore

      def initialize(vm_id, data)
        super
        @vm = Models::Vm[vm_id]

        if @vm.nil?
          handler_error("VM `#{vm_id}' is no longer in the database")
        end

        if @vm.agent_id.nil?
          handler_error("VM `#{vm_id}' doesn't have an agent id")
        end
      end

      def description
        "#{instance_name(@vm)} (#{@vm.cid}) is not responding"
      end

      resolution :ignore do
        plan { 'Skip for now' }
        action { }
      end

      resolution :reboot_vm do
        plan { 'Reboot VM' }
        action { validate; ensure_cid; reboot_vm(@vm) }
      end

      resolution :recreate_vm do
        plan { 'Recreate VM' }
        action { validate; ensure_cid; recreate_vm(@vm) }
      end

      resolution :delete_vm_reference do
        plan { 'Delete VM reference (forceful; may need to manually delete VM from the Cloud to avoid IP conflicts)' }
        action { validate; delete_vm_reference(@vm, skip_cid_check: true) }
      end

      def agent_alive?
        agent_client(@vm).ping
        true
      rescue Bosh::Director::RpcTimeout
        false
      end

      def ensure_cid
        if @vm.cid.nil?
          handler_error("VM `#{@vm.id}' doesn't have a cloud id, " +
              'only resolution is to delete the VM reference.')
        end
      end

      def ensure_no_cid
        if @vm.cid
          handler_error("VM `#{@vm.id}' has a cloud id, " +
              'please use a different resolution.')
        end
      end

      def validate
        if agent_alive?
          handler_error('Agent is responding now, skipping resolution')
        end
      end

      def delete_vm
      end
    end
  end
end
