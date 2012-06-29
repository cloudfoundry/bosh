# Copyright (c) 2009-2012 VMware, Inc.

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
        plan { "Ignore problem" }
        action { }
      end

      resolution :reboot_vm do
        plan { "Reboot VM" }
        action { validate; ensure_cid; reboot_vm(@vm) }
      end

      resolution :recreate_vm do
        plan { "Recreate VM using last known apply spec" }
        action { validate; ensure_cid; recreate_vm(@vm) }
      end

      resolution :delete_vm_reference do
        plan { "Delete VM reference (DANGEROUS!)" }
        action { validate; ensure_no_cid; delete_vm_reference(@vm) }
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
                            "only resolution is to delete the VM reference.")
        end
      end

      def ensure_no_cid
        if @vm.cid
          handler_error("VM `#{@vm.id}' has a cloud id, " +
                            "please use a different resolution.")
        end
      end

      def validate
        # TODO: think about flapping agent problem
        if agent_alive?
          handler_error("Agent is responding now, skipping resolution")
        end
      end

      def delete_vm
        # TODO: this is useful to kill stuck compilation VMs
      end

    end
  end
end
