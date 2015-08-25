# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module CloudcheckHelper
    # Helper functions that come in handy for
    # cloudcheck:
    # 1. VM/agent interactions
    # 2. VM lifecycle operations (from cloudcheck POV)
    # 3. Error handling

    # This timeout has been made pretty short mainly
    # to avoid long cloudchecks, however 10 seconds should
    # still be pretty generous interval for agent to respond.
    DEFAULT_AGENT_TIMEOUT = 10

    def cloud
      Bosh::Director::Config.cloud
    end

    def handler_error(message)
      raise Bosh::Director::ProblemHandlerError, message
    end

    def instance_name(vm)
      instance = vm.instance
      return "Unknown VM" if instance.nil?

      job = instance.job || "unknown job"
      index = instance.index || "unknown index"
      "#{job}/#{index}"
    end

    def agent_client(vm, timeout = DEFAULT_AGENT_TIMEOUT, retries = 0)
      options = {
        :timeout => timeout,
        :retry_methods => { :get_state => retries }
      }
      @clients ||= {}
      @clients[vm.agent_id] ||= AgentClient.with_vm(vm, options)
    end

    def agent_timeout_guard(vm, &block)
      yield agent_client(vm)
    rescue Bosh::Director::RpcTimeout
      handler_error("VM `#{vm.cid}' is not responding")
    end

    def reboot_vm(vm)
      cloud.reboot_vm(vm.cid)
      begin
        agent_client(vm).wait_until_ready
      rescue Bosh::Director::RpcTimeout
        handler_error('Agent still unresponsive after reboot')
      end
    end

    def delete_vm(vm)
      # Paranoia: don't blindly delete VMs with persistent disk
      disk_list = agent_timeout_guard(vm) { |agent| agent.list_disk }
      if disk_list.size != 0
        handler_error('VM has persistent disk attached')
      end

      vm_deleter.delete_vm(vm)
    end

    def delete_vm_reference(vm, options={})
      if vm.cid && !options[:skip_cid_check]
        handler_error('VM has a CID')
      end

      vm.destroy
    end

    def recreate_vm(vm)
      @logger.debug("Recreating Vm: #{vm.inspect}")
      unless vm.instance
        handler_error('VM does not have an associated instance')
      end
      instance_model = vm.instance

      handler_error("VM doesn't belong to any deployment") unless vm.deployment

      validate_spec(vm.apply_spec)
      validate_env(vm.env)

      instance = DeploymentPlan::ExistingInstance.create_from_model(instance_model, @logger)

      begin
        vm_deleter.delete_for_instance(instance, skip_disks: true)
      rescue Bosh::Clouds::VMNotFound
        # One situation where this handler is actually useful is when
        # VM has already been deleted but something failed after that
        # and it is still referenced in DB. In that case it makes sense
        # to ignore "VM not found" errors in `delete_vm' and let the method
        # proceed creating a new VM. Other errors are not forgiven.

        @logger.warn("VM '#{vm.cid}' might have already been deleted from the cloud")
      end

      instance_plan = DeploymentPlan::InstancePlan.create_from_deployment_plan_instance(instance)

      vm_creator.create_for_instance_plan(
        instance_plan,
        Array(instance_model.persistent_disk_cid)
      )

      if instance_model.state == 'started'
        agent_client(instance.vm.model).start
      end
    end

    private

    def vm_deleter
      @vm_deleter ||= VmDeleter.new(cloud, @logger)
    end

    def vm_creator
      @vm_creator ||= VmCreator.new(cloud, @logger, vm_deleter)
    end

    def validate_spec(spec)
      handler_error('Unable to look up VM apply spec') unless spec

      unless spec.kind_of?(Hash)
        handler_error('Invalid apply spec format')
      end
    end

    def validate_env(env)
      handler_error('Unable to look up VM environment') unless env

      unless env.kind_of?(Hash)
        handler_error('Invalid VM environment format')
      end
    end

    def generate_agent_id
      SecureRandom.uuid
    end
  end
end
