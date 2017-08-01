module Bosh::Director
  class Errand::LifecycleErrandStep
    def initialize(runner, deployment_planner, name, instance, instance_group, skip_errand, keep_alive, deployment_name, logger)
      @runner = runner
      @deployment_planner = deployment_planner
      @name = name
      @instance = instance
      @instance_group = instance_group
      @skip_errand = skip_errand
      @keep_alive = keep_alive
      @logger = logger
      @deployment_name = deployment_name
      instance_group_manager = Errand::InstanceGroupManager.new(@deployment_planner, @instance_group, @logger)
      @errand_instance_updater = Errand::ErrandInstanceUpdater.new(instance_group_manager, @logger, @name, @deployment_name)
    end

    def prepare
      return if @skip_errand
      @errand_instance_updater.create_vms(@keep_alive)
    end

    def run(&checkpoint_block)
      if @skip_errand
        @logger.info('Skip running errand because since last errand run was successful and there have been no changes to job configuration')
        return
      end

      result = nil
      @errand_instance_updater.with_updated_instances(@instance_group, @keep_alive) do
        @logger.info('Starting to run errand')
        result = @runner.run(@instance, &checkpoint_block)
      end
      result.short_description(@name)
    ensure
      @deployment_planner.template_blob_cache.clean_cache!
    end

    def ignore_cancellation?
      @errand_instance_updater && @errand_instance_updater.ignore_cancellation?
    end
  end
end
