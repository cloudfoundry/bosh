module Bosh::Director
  module ProblemHandlers
    class UnresponsiveAgent < Base

      register_as :unresponsive_agent
      auto_resolution :ignore

      def initialize(vm_id, data)
        super
        @vm_id = vm_id
        @vm = Models::Vm[@vm_id]
        @agent_id = @vm.agent_id
        @agent = AgentClient.new(@agent_id)
      end

      def problem_still_exists?
        @agent.wait_until_ready
        false
      rescue Bosh::Director::Client::TimeoutException
        true
      end

      def description
        "Agent #{@agent_id} in VM #{@vm_id} is NOT responding"
      end

      resolution :ignore do
        plan { "Report problem" }
        action { }
      end

      resolution :reboot_vm do
        plan { "Reboot vm #{@vm_id}" }
        action { reboot_vm }
      end

      def reboot_vm
        cloud.reboot_vm(@vm.cid)
        handler_error("Agent still unresponsive after reboot") if problem_still_exists?
      end
    end
  end
end
