# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module CloudcheckHelper
    include CloudFactoryHelper
    # Helper functions that come in handy for
    # cloudcheck:
    # 1. VM/agent interactions
    # 2. VM lifecycle operations (from cloudcheck POV)
    # 3. Error handling

    # This timeout has been made pretty short mainly
    # to avoid long cloudchecks, however 10 seconds should
    # still be pretty generous interval for agent to respond.
    DEFAULT_AGENT_TIMEOUT = 10

    def reboot_vm(instance)
      cloud = cloud_factory.for_availability_zone(instance.availability_zone)
      cloud.reboot_vm(instance.vm_cid)
      begin
        agent_client(instance.credentials, instance.agent_id).wait_until_ready
      rescue Bosh::Director::RpcTimeout
        handler_error('Agent still unresponsive after reboot')
      rescue Bosh::Director::TaskCancelled
        handler_error('Task was cancelled')
      end
    end

    def delete_vm(instance)
      # Paranoia: don't blindly delete VMs with persistent disk
      disk_list = agent_timeout_guard(instance.vm_cid, instance.credentials, instance.agent_id) { |agent| agent.list_disk }
      if disk_list.size != 0
        handler_error('VM has persistent disk attached')
      end

      vm_deleter.delete_for_instance(instance)
    end

    def delete_vm_reference(instance)
      instance.update(vm_cid: nil, agent_id: nil, trusted_certs_sha1: nil, credentials: nil)
    end

    def delete_vm_from_cloud(instance_model)
      @logger.debug("Deleting Vm: #{instance_model})")

      validate_spec(instance_model.spec)
      validate_env(instance_model.vm_env)

      vm_deleter.delete_for_instance(instance_model)
    end

    def recreate_vm_skip_post_start(instance_model)
      recreate_vm(instance_model, false)
    end

    def recreate_vm(instance_model, run_post_start = true)
      @logger.debug("Recreating Vm: #{instance_model})")
      delete_vm_from_cloud(instance_model)

      instance_plan_to_create = create_instance_plan(instance_model)
      job_renderer = JobRenderer.create
      vm_creator(job_renderer).create_for_instance_plan(
        instance_plan_to_create,
        Array(instance_model.managed_persistent_disk_cid),
        instance_plan_to_create.tags
      )

      dns_manager = DnsManagerProvider.create
      dns_names_to_ip = {}

      apply_spec = instance_plan_to_create.existing_instance.spec
      apply_spec['networks'].each do |network_name, network|
        index_dns_name = dns_manager.dns_record_name(instance_model.index, instance_model.job, network_name, instance_model.deployment.name)
        dns_names_to_ip[index_dns_name] = network['ip']
        id_dns_name = dns_manager.dns_record_name(instance_model.uuid, instance_model.job, network_name, instance_model.deployment.name)
        dns_names_to_ip[id_dns_name] = network['ip']
      end

      @logger.debug("Updating DNS record for instance: #{instance_model.inspect}; to: #{dns_names_to_ip.inspect}")
      dns_manager.update_dns_record_for_instance(instance_model, dns_names_to_ip)
      dns_manager.flush_dns_cache

      cloud_check_procedure = lambda do
        blobstore_client = App.instance.blobstores.blobstore

        cleaner = RenderedJobTemplatesCleaner.new(instance_model, blobstore_client, @logger)
        templates_persister = RenderedTemplatesPersister.new(blobstore_client, @logger)

        templates_persister.persist(instance_plan_to_create)

        # for backwards compatibility with instances that don't have update config
        update_config = apply_spec['update'].nil? ? nil : DeploymentPlan::UpdateConfig.new(apply_spec['update'])

        InstanceUpdater::StateApplier.new(
          instance_plan_to_create,
          agent_client(instance_model.credentials, instance_model.agent_id),
          cleaner,
          @logger,
          {}
        ).apply(update_config, run_post_start)
      end
      InstanceUpdater::InstanceState.with_instance_update(instance_model, &cloud_check_procedure)
    ensure
      job_renderer.clean_cache! if job_renderer
    end

    private

    def create_instance_plan(instance_model)
      env = DeploymentPlan::Env.new(instance_model.vm_env)
      stemcell = DeploymentPlan::Stemcell.parse(instance_model.spec['stemcell'])
      stemcell.add_stemcell_models
      stemcell.deployment_model = instance_model.deployment
      # FIXME cpi is not passed here (otherwise, we would need to parse the CPI using the cloud config & cloud manifest parser)
      # it is not a problem, since all interactions with cpi go over cloud factory (which uses only az name)
      # but still, it is ugly and dangerous...
      availability_zone = DeploymentPlan::AvailabilityZone.new(instance_model.availability_zone,
                                                               instance_model.cloud_properties_hash,
                                                               nil)

      instance_from_model = DeploymentPlan::Instance.new(
        instance_model.job,
        instance_model.index,
        instance_model.state,
        instance_model.cloud_properties_hash,
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
        recreate_deployment: true,
        tags: instance_from_model.deployment_model.tags
      )
    end

    def handler_error(message)
      raise Bosh::Director::ProblemHandlerError, message
    end

    def agent_client(vm_credentials, agent_id, timeout = DEFAULT_AGENT_TIMEOUT, retries = 0)
      options = {
        :timeout => timeout,
        :retry_methods => { :get_state => retries }
      }
      @clients ||= {}
      @clients[agent_id] ||= AgentClient.with_vm_credentials_and_agent_id(vm_credentials, agent_id, options)
    end

    def agent_timeout_guard(vm_cid, vm_credentials, agent_id, &block)
      yield agent_client(vm_credentials, agent_id)
    rescue Bosh::Director::RpcTimeout
      handler_error("VM '#{vm_cid}' is not responding")
    end

    def vm_deleter
      @vm_deleter ||= VmDeleter.new(@logger, false, Config.enable_virtual_delete_vms)
    end

    def vm_creator(job_renderer)
      disk_manager = DiskManager.new(@logger)
      agent_broadcaster = AgentBroadcaster.new
      @vm_creator ||= VmCreator.new(@logger, vm_deleter, disk_manager, job_renderer, agent_broadcaster)
    end

    def validate_spec(spec)
      handler_error('Unable to look up VM apply spec') unless spec

      unless spec.kind_of?(Hash)
        handler_error('Invalid apply spec format')
      end
    end

    def validate_env(env)
      unless env.kind_of?(Hash)
        handler_error('Invalid VM environment format')
      end
    end

    def generate_agent_id
      SecureRandom.uuid
    end
  end
end
