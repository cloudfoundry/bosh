# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module ProblemHandlers
    class UnboundInstanceVm < Base

      register_as :unbound_instance_vm
      auto_resolution :reassociate_vm

      def initialize(vm_id, data)
        super

        @vm = Models::Vm[vm_id]
        @data = data

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
        job = @data["job"] || "unknown job"
        index = @data["index"] || "unknown index"
        "VM `#{@vm.cid}' reports itself as `#{job}/#{index}' but does not have a bound instance"
      end

      resolution :ignore do
        plan { "Skip for now" }
        action { }
      end

      resolution :delete_vm do
        plan { "Delete VM (unless it has persistent disk)" }
        action { validate; delete_vm(@vm) }
      end

      resolution :reassociate_vm do
        plan { "Reassociate VM with corresponding instance" }
        action { validate; reassociate_vm }
      end

      def validate
        unless @vm.instance.nil?
          handler_error("Instance is now bound to VM")
        end

        state = agent_timeout_guard(@vm) { |agent| agent.get_state }
        if state["job"].nil?
          handler_error("VM now properly reports no job")
        end
      end

      def reassociate_vm
        instances = Models::Instance.
          filter(:deployment_id => @vm.deployment_id,
                 :job => @data["job"], :index => @data["index"]).all

        if instances.size > 1
          handler_error("More than one instance in DB matches this VM")
        end

        if instances.empty?
          handler_error("No instances in DB match this VM")
        end

        instance = instances[0]

        if instance.vm
          handler_error("The corresponding instance is associated with another VM")
        end

        instance.update(:vm => @vm)
      end
    end
  end
end
