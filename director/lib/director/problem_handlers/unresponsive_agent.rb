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

        if @vm.cid.nil?
          handler_error("VM `#{vm_id}' doesn't have a cloud id")
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
        action { validate; reboot_vm(@vm) }
      end

      resolution :recreate_vm do
        plan { "Recreate VM using last known apply spec" }
        action { validate; recreate_vm(@vm) }
      end

      def agent_alive?
        agent_client(@vm).ping
        true
      rescue Bosh::Director::Client::TimeoutException
        false
      end

      def validate
        # TODO: think about flapping agent problem
        if agent_alive?
          handler_error("Agent is responding now, skipping reboot")
        end
      end

      def delete_vm
        # TODO: this is useful to kill stuck compilation VMs
      end

    end
  end
end
