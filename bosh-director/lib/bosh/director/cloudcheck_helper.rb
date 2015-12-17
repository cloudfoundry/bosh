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

    def reboot_vm(vm)
      cloud.reboot_vm(vm.cid)
      begin
        agent_client(vm).wait_until_ready
      rescue Bosh::Director::RpcTimeout
        handler_error('Agent still unresponsive after reboot')
      rescue Bosh::Director::TaskCancelled
        handler_error('Task was cancelled')
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
      vm_env = vm.env

      handler_error("VM doesn't belong to any deployment") unless vm.deployment
      handler_error('Failed to recreate VM without instance') unless vm.instance

      validate_spec(vm.instance.spec)
      validate_env(vm.env)

      instance_plan_to_delete = DeploymentPlan::InstancePlan.new(
        existing_instance: instance_model,
        instance: nil,
        desired_instance: nil,
        network_plans: []
      )

      begin
        vm_deleter.delete_for_instance_plan(instance_plan_to_delete)
      rescue Bosh::Clouds::VMNotFound
        # One situation where this handler is actually useful is when
        # VM has already been deleted but something failed after that
        # and it is still referenced in DB. In that case it makes sense
        # to ignore "VM not found" errors in `delete_vm' and let the method
        # proceed creating a new VM. Other errors are not forgiven.

        @logger.warn("VM '#{vm.cid}' might have already been deleted from the cloud")
      end

      instance_plan_to_create = create_instance_plan(instance_model, vm_env)

      vm_creator.create_for_instance_plan(
        instance_plan_to_create,
        Array(instance_model.persistent_disk_cid)
      )

      dns_manager = DnsManager.create
      dns_names_to_ip = {}

      instance_plan_to_create.existing_instance.spec['networks'].each do |network_name, network|
        index_dns_name = dns_manager.dns_record_name(instance_model.index, instance_model.job, network_name, instance_model.deployment.name)
        dns_names_to_ip[index_dns_name] = network['ip']
        id_dns_name = dns_manager.dns_record_name(instance_model.uuid, instance_model.job, network_name, instance_model.deployment.name)
        dns_names_to_ip[id_dns_name] = network['ip']
      end

      @logger.debug("Updating DNS record for instance: #{instance_model.inspect}; to: #{dns_names_to_ip.inspect}")
      dns_manager.update_dns_record_for_instance(instance_model, dns_names_to_ip)
      dns_manager.flush_dns_cache

      cleaner = RenderedJobTemplatesCleaner.new(instance_model, App.instance.blobstores.blobstore, @logger)
      InstanceUpdater::StateApplier.new(instance_plan_to_create, agent_client(instance_model.vm), cleaner).apply
    end

    private

    def create_instance_plan(instance_model, vm_env)
      vm_type = DeploymentPlan::VmType.new(instance_model.spec['vm_type'])
      env = DeploymentPlan::Env.new(vm_env)
      stemcell = DeploymentPlan::Stemcell.new(instance_model.spec['stemcell'])
      stemcell.add_stemcell_model
      availability_zone = DeploymentPlan::AvailabilityZone.new(instance_model.availability_zone, instance_model.cloud_properties_hash)

      instance_from_model = DeploymentPlan::Instance.new(
        instance_model.job,
        instance_model.index,
        instance_model.state,
        vm_type,
        stemcell,
        env,
        false,
        instance_model.deployment,
        instance_model.spec,
        availability_zone,
        @logger
      )
      instance_from_model.bind_existing_instance_model(instance_model)

      DeploymentPlan::ResurrectionInstancePlan.new(
        existing_instance: instance_model,
        instance: instance_from_model,
        desired_instance: DeploymentPlan::DesiredInstance.new,
        recreate_deployment: true
      )
    end

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

    def vm_deleter
      @vm_deleter ||= VmDeleter.new(cloud, @logger)
    end

    def vm_creator
      disk_manager = DiskManager.new(cloud, @logger)
      job_renderer = JobRenderer.create
      @vm_creator ||= VmCreator.new(cloud, @logger, vm_deleter, disk_manager, job_renderer)
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
