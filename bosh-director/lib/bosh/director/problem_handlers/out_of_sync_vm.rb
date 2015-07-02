# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module ProblemHandlers
    class OutOfSyncVm < Base

      register_as :out_of_sync_vm
      auto_resolution :ignore

      def initialize(vm_id, data)
        super
        @vm = Models::Vm[vm_id]
        @data = data

        if @vm.nil?
          handler_error("VM `#{vm_id}' is no longer in the database")
        end

        @deployment = @vm.deployment
        @instance = @vm.instance

        if @deployment.nil?
          handler_error("VM `#{@vm.cid}' doesn't belong to any deployment")
        end

      end

      def description
        actual_deployment = @data["deployment"] || "unknown deployment"
        actual_job = @data["job"] || "unknown job"
        actual_index = @data["index"] || "unknown index"

        expected = "#{@deployment.name}: #{instance_name(@vm)}"
        actual = "#{actual_deployment}: #{actual_job}/#{actual_index}"

        "VM `#{@vm.cid}' is out of sync: expected `#{expected}', got `#{actual}'"
      end

      resolution :ignore do
        plan { "Skip for now" }
        action { }
      end

      resolution :delete_vm do
        plan { "Delete VM (unless it has persistent disk)"}
        action { validate; delete_vm(@vm) }
      end

      def validate
        state = agent_timeout_guard(@vm) { |agent | agent.get_state }
        return if state["deployment"] != @deployment.name

        # VM is no longer out of sync if no instance is referencing it,
        # as this situation can actually be handled by regular deployment
        if @instance.nil? ||
            state["job"] && state["job"]["name"] == @instance.job &&
            state["index"] == @instance.index
          handler_error("VM is now back in sync")
        end
      end

    end
  end
end
