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
        instance = @vm.instance
        if instance.nil?
          vm_description = "Unknown VM"
        else
          job = instance.job || "unknown job"
          index = instance.index || "unknown index"
          vm_description = "#{job}/#{index}"
        end
        "#{vm_description} (#{@vm.cid}) is not responding"
      end

      resolution :ignore do
        plan { "Ignore problem" }
        action { }
      end

      resolution :reboot_vm do
        plan { "Reboot VM" }
        action { reboot_vm }
      end

      def agent_alive?
        agent_client(@vm).ping
        true
      rescue Bosh::Director::Client::TimeoutException
        false
      end

      def reboot_vm
        # TODO: think about flapping agent problem
        if agent_alive?
          handler_error("Agent is responding now, skipping reboot")
        end

        cloud.reboot_vm(@vm.cid)
        begin
          agent_client(@vm).wait_until_ready
        rescue Bosh::Director::Client::TimeoutException
          handler_error("Agent still unresponsive after reboot")
        end
      end

    end
  end
end
