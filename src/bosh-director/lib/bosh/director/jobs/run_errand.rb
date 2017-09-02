module Bosh::Director
  class Jobs::RunErrand < Jobs::BaseJob

    @queue = :normal

    def self.job_type
      :run_errand
    end

    def initialize(deployment_name, errand_name, keep_alive, when_changed, instances)
      @deployment_name = deployment_name
      @errand_name = errand_name
      @keep_alive = keep_alive
      @when_changed = when_changed
      @instance_manager = Api::InstanceManager.new
      @instances = instances
      blobstore = App.instance.blobstores.blobstore
      log_bundles_cleaner = LogBundlesCleaner.new(blobstore, 60 * 60 * 24 * 10, logger) # 10 days
      @logs_fetcher = LogsFetcher.new(@instance_manager, log_bundles_cleaner, logger)
    end

    def perform
      lock_helper = LockHelperImpl.new

      lock_helper.with_deployment_lock(@deployment_name) do
        deployment_plan_provider = Errand::DeploymentPlannerProvider.new(logger)
        errand_provider = Errand::ErrandProvider.new(@logs_fetcher, @instance_manager, event_manager, logger, task_result, deployment_plan_provider)
        @errand = errand_provider.get(@deployment_name, @errand_name, @keep_alive, @instances)

        if @when_changed && @errand.has_not_changed_since_last_success?
          return 'skipped - no changes detected'
        end

        @errand.prepare

        checkpoint_block = lambda { task_checkpoint }
        errand_results = @errand.run(&checkpoint_block)

        Errand::ResultSet.new(errand_results).summary
      end
    end

    def task_cancelled?
      if @errand && @errand.ignore_cancellation?
        false
      else
        super
      end
    end
  end
end
