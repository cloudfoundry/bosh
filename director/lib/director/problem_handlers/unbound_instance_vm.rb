module Bosh::Director
  module ProblemHandlers
    class UnboundInstanceVm < Base

      register_as :unbound_instance_vm
      auto_resolution :ignore

      def initialize(vm_id, data)
        super

        @vm = Models::Vm[vm_id]
        @job = data["job"] || "unknown job"
        @index = data["index"] || "unknown index"

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
        "VM `#{@vm.cid}' reports itself as `#{@job}/#{@index}' but does not have a bound instance"
      end

      resolution :ignore do
        plan { "Ignore problem" }
        action { }
      end

      resolution :delete_vm do
        plan { "Delete VM (unless it has persistent disk)" }
        action { delete_vm }
      end

      def delete_vm
        unless @vm.instance.nil?
          handler_error("Instance is now bound to VM")
        end

        agent = agent_client(@vm)
        state = agent.get_state

        if state["job"].nil?
          handler_error("VM now properly reports no job")
        end

        # Paranoia: agent/vm without an instance should never have persistent disk
        disk_list = agent.list_disk
        if disk_list.size != 0
          handler_error("VM has persistent disk attached")
        end

        cloud.delete_vm(@vm.cid)
        @vm.destroy
      rescue Bosh::Director::Client::TimeoutException
        handler_error("VM is not responding")
      end
    end
  end
end
