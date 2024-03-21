module Bosh::Director
  class Errand::InstanceGroupManager
    def initialize(deployment_planner, instance_group, logger)
      @deployment_planner = deployment_planner
      @instance_group = instance_group
      @logger = logger
      @disk_manager = DiskManager.new(logger)
      @template_blob_cache = @deployment_planner.template_blob_cache
      agent_broadcaster = AgentBroadcaster.new
      @dns_encoder = LocalDnsEncoderManager.create_dns_encoder(
        @deployment_planner.use_short_dns_addresses?,
        @deployment_planner.use_link_dns_names?,
      )
      @vm_deleter = VmDeleter.new(logger, false, Config.enable_virtual_delete_vms)
      @vm_creator = VmCreator.new(
        logger,
        @template_blob_cache,
        @dns_encoder,
        agent_broadcaster,
        @deployment_planner.link_provider_intents,
      )
    end

    def create_missing_vms
      @vm_creator.create_for_instance_plans(
        @instance_group.instance_plans_with_missing_vms,
        @deployment_planner.ip_provider, @deployment_planner.tags
      )
    end

    # Creates/updates all errand job instances
    # @return [void]
    def update_instances
      instance_group_updater = InstanceGroupUpdater.new(
        ip_provider: @deployment_planner.ip_provider,
        instance_group: @instance_group,
        disk_manager: @disk_manager,
        template_blob_cache: @template_blob_cache,
        dns_encoder: @dns_encoder,
        link_provider_intents: @deployment_planner.link_provider_intents,
      )
      instance_group_updater.update
    end

    def delete_vms
      bound_instance_plans = @instance_group.needed_instance_plans.reject { |instance_plan| instance_plan.instance.model.nil? }
      if bound_instance_plans.empty?
        @logger.info('No errand vms to delete')
        return
      end

      bound_instance_plans.each do |instance_plan|
        instance_model = instance_plan.instance.model

        unless instance_plan.already_detached?
          DeploymentPlan::Steps::UnmountInstanceDisksStep.new(instance_model).perform(DeploymentPlan::Stages::Report.new)
        end

        @vm_deleter.delete_for_instance(instance_model)
        LocalDnsManager.create(Config.root_domain, @logger).delete_dns_for_instance(instance_model)
        instance_model.remove_all_templates
      end
    end

    private

    def bound_instance_plans
      @instance_group.needed_instance_plans.reject do |instance_plan|
        instance_plan.instance.nil? || instance_plan.instance.model.nil?
      end
    end
  end
end
