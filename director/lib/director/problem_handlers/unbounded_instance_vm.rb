module Bosh::Director
  module ProblemHandlers
    class UnboundedInstanceVm < Base
      register_as :unbounded_instance_vm
      auto_resolution :ignore

      def initialize(vm_id, data)
        @vm_id = vm_id
        @vm = Models::Vm[@vm_id]
        @agent_id = @vm.agent_id
        @agent = AgentClient.new(@agent_id)
        @state = data
        if @state["job"].nil?
          handler_error("Agent #{@agent_id} does not have a job in the state")
        end
      end

      def problem_still_exists?
        state = @agent.get_state
        @vm.instance.nil? && !state["job"].nil?
      end

      def description
        "Agent #{@agent_id} - #{@state["job"]["name"]} - does not have an instance"
      end

      resolution :ignore do
        plan { "Ignore problem" }
        action { }
      end

      resolution :delete_vm do
        plan { "Delete the VM" }
        action { delete_vm }
      end

      def delete_vm
        # Paranoia. agent/vm without an instance should never have a disk
        disk_list = @agent.list_disk
        if disk_list.size != 0
          handler_error("Agent reports a persistent disk (#{disk_list.first})")
        end

        cloud.delete_vm(@vm.cid)
        @vm.destroy
      end
    end
  end
end
