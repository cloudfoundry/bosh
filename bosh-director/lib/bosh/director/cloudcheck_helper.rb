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
      vm_apply_spec = vm.apply_spec
      vm_env = vm.env

      handler_error("VM doesn't belong to any deployment") unless vm.deployment

      validate_spec(vm.apply_spec)
      validate_env(vm.env)

      instance_plan_to_delete = DeploymentPlan::InstancePlan.new(
        existing_instance: instance_model,
        instance: nil,
        desired_instance: nil,
        network_plans: []
      )

      begin
        vm_deleter.delete_for_instance_plan(instance_plan_to_delete, skip_disks: true)
      rescue Bosh::Clouds::VMNotFound
        # One situation where this handler is actually useful is when
        # VM has already been deleted but something failed after that
        # and it is still referenced in DB. In that case it makes sense
        # to ignore "VM not found" errors in `delete_vm' and let the method
        # proceed creating a new VM. Other errors are not forgiven.

        @logger.warn("VM '#{vm.cid}' might have already been deleted from the cloud")
      end

      # FIXME: Try to reduce dependencies
      instance_model.bind_to_vm_model(vm)
      deployment_model = instance_model.deployment
      deployment_plan_from_model = DeploymentPlan::Planner.new(
        {name: deployment_model.name, properties: deployment_model.properties},
        deployment_model.manifest,
        deployment_model.cloud_config,
        deployment_model,
        {'recreate' => true})

      job_from_instance_model = DeploymentPlan::Job.new(@logger)
      job_from_instance_model.name = instance_model.job
      job_from_instance_model.vm_type = DeploymentPlan::VmType.new(vm_apply_spec['vm_type'])
      job_from_instance_model.env = DeploymentPlan::Env.new(vm_env)
      stemcell = DeploymentPlan::Stemcell.new(vm_apply_spec['stemcell'])
      stemcell.add_stemcell_model
      job_from_instance_model.stemcell = stemcell

      availability_zone = DeploymentPlan::AvailabilityZone.new(instance_model.availability_zone, instance_model.cloud_properties_hash)

      instance_from_model = DeploymentPlan::Instance.new(
        job_from_instance_model,
        instance_model.index,
        instance_model.state,
        deployment_plan_from_model,
        vm_apply_spec,
        availability_zone,
        instance_model.bootstrap,
        @logger
      )
      instance_from_model.bind_existing_instance_model(instance_model)

      instance_plan_to_create = DeploymentPlan::InstancePlan.new(
        existing_instance: instance_model,
        instance: instance_from_model,
        desired_instance: DeploymentPlan::DesiredInstance.new,
        network_plans: [],
        recreate_deployment: true
      )

      vm_creator.create_for_instance_plan(
        instance_plan_to_create,
        Array(instance_model.persistent_disk_cid)
      )

      if instance_model.state == 'started'
        agent_client(instance_model.vm).run_script('pre-start', {})
        agent_client(instance_model.vm).start
      end
    end

    private

    def vm_deleter
      @vm_deleter ||= VmDeleter.new(cloud, @logger)
    end

    def vm_creator
      disk_manager = DiskManager.new(cloud, @logger)
      @vm_creator ||= VmCreator.new(cloud, @logger, vm_deleter, disk_manager)
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
