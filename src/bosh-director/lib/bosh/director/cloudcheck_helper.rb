module Bosh::Director
  module CloudcheckHelper
    include IpUtil
    # Helper functions that come in handy for
    # cloudcheck:
    # 1. VM/agent interactions
    # 2. VM lifecycle operations (from cloudcheck POV)
    # 3. Error handling

    def reboot_vm(instance)
      vm = instance.active_vm

      cloud = CloudFactory.create.get(vm.cpi)
      cloud.reboot_vm(vm.cid)

      begin
        agent_client(instance.agent_id, instance.name).wait_until_ready
      rescue Bosh::Director::RpcTimeout
        handler_error('Agent still unresponsive after reboot')
      rescue Bosh::Director::TaskCancelled
        handler_error('Task was cancelled')
      end
    end

    def delete_vm(instance)
      # Paranoia: don't blindly delete VMs with persistent disk
      disk_list = agent_timeout_guard(instance.vm_cid, instance.agent_id, instance.name, &:list_disk)

      handler_error('VM has persistent disk attached') unless disk_list.empty?

      vm_deleter.delete_for_instance(instance)
    end

    def delete_vm_reference(instance)
      vm_model = instance.active_vm
      instance.active_vm = nil
      vm_model&.destroy
    end

    def delete_vm_from_cloud(instance_model)
      @logger.debug("Deleting Vm: #{instance_model})")

      validate_spec(instance_model.spec)
      validate_env(instance_model.vm_env)

      vm_deleter.delete_for_instance(instance_model)
    end

    def recreate_vm_without_wait(instance_model)
      recreate_vm(instance_model, false)
    end

    def recreate_vm(instance_model, wait_for_running = true)
      @logger.debug("Recreating Vm: #{instance_model})")
      delete_vm_from_cloud(instance_model)

      deployment_model = instance_model.deployment
      factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(@logger)
      planner = factory.create_from_model(deployment_model)
      dns_encoder = LocalDnsEncoderManager.create_dns_encoder(planner.use_short_dns_addresses?, planner.use_link_dns_names?)

      instance_plan_to_create = create_instance_plan(instance_model, planner)

      Bosh::Director::Core::Templates::TemplateBlobCache.with_fresh_cache do |template_cache|
        vm_creator(template_cache, dns_encoder, planner.link_provider_intents)
          .create_for_instance_plan(
            instance_plan_to_create,
            planner.ip_provider,
            Array(instance_model.managed_persistent_disk_cid),
            instance_plan_to_create.tags,
            true,
          )

        local_dns_manager = LocalDnsManager.create(Config.root_domain, @logger)
        dns_names_to_ip = {}

        root_domain = Config.root_domain

        apply_spec = instance_plan_to_create.existing_instance.spec
        apply_spec['networks'].each do |network_name, network|
          index_dns_name = Bosh::Director::DnsNameGenerator.dns_record_name(
            instance_model.index,
            instance_model.job,
            network_name,
            instance_model.deployment.name,
            root_domain,
          )
          dns_names_to_ip[index_dns_name] = network['ip']

          id_dns_name = Bosh::Director::DnsNameGenerator.dns_record_name(
            instance_model.uuid,
            instance_model.job,
            network_name,
            instance_model.deployment.name,
            root_domain,
          )
          dns_names_to_ip[id_dns_name] = network['ip']
        end

        @logger.debug("Updating DNS record for instance: #{instance_model.inspect}; to: #{dns_names_to_ip.inspect}")
        local_dns_manager.update_dns_record_for_instance(instance_plan_to_create)

        cloud_check_procedure = lambda do
          blobstore_client = App.instance.blobstores.blobstore

          cleaner = RenderedJobTemplatesCleaner.new(instance_model, blobstore_client, @logger)
          templates_persister = RenderedTemplatesPersister.new(blobstore_client, @logger)

          templates_persister.persist(instance_plan_to_create)

          # for backwards compatibility with instances that don't have update config
          update_config = apply_spec['update'].nil? ? nil : DeploymentPlan::UpdateConfig.new(apply_spec['update'])

          InstanceUpdater::StateApplier.new(
            instance_plan_to_create,
            agent_client(instance_model.agent_id, instance_model.name),
            cleaner,
            @logger,
            {},
          ).apply(update_config, wait_for_running)
        end

        InstanceUpdater::InstanceState.with_instance_update(instance_model, &cloud_check_procedure)
      end
    end

    private

    def create_instance_plan(instance_model, deployment_plan)
      variables_interpolator = Bosh::Director::ConfigServer::VariablesInterpolator.new
      instance_repo = DeploymentPlan::InstanceRepository.new(@logger, variables_interpolator)
      instance_from_model = instance_repo.build_instance_from_model(instance_model, {}, instance_model.state, deployment_plan)

      DeploymentPlan::InstancePlanFromDB.new(
        existing_instance: instance_model,
        instance: instance_from_model,
        desired_instance: DeploymentPlan::DesiredInstance.new,
        recreate_deployment: true,
        tags: instance_from_model.deployment_model.tags,
        variables_interpolator: variables_interpolator,
        link_provider_intents: deployment_plan.link_provider_intents,
      )
    end

    def handler_error(message)
      raise Bosh::Director::ProblemHandlerError, message
    end

    def agent_client(agent_id, instance_name)
      @clients ||= {}
      @clients[agent_id] ||= AgentClient.with_agent_id(agent_id, instance_name)
    end

    def agent_timeout_guard(vm_cid, agent_id, instance_name)
      yield agent_client(agent_id, instance_name)
    rescue Bosh::Director::RpcTimeout
      handler_error("VM '#{vm_cid}' is not responding")
    end

    def vm_deleter
      @vm_deleter ||= VmDeleter.new(@logger, false, Config.enable_virtual_delete_vms)
    end

    def vm_creator(template_cache, dns_encoder, link_provider_intents)
      agent_broadcaster = AgentBroadcaster.new
      @vm_creator ||= VmCreator.new(@logger, template_cache, dns_encoder, agent_broadcaster, link_provider_intents)
    end

    def validate_spec(spec)
      handler_error('Unable to look up VM apply spec') unless spec

      handler_error('Invalid apply spec format') unless spec.is_a?(Hash)
    end

    def validate_env(env)
      handler_error('Invalid VM environment format') unless env.is_a?(Hash)
    end

    def generate_agent_id
      SecureRandom.uuid
    end
  end
end
