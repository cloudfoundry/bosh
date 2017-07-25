module Bosh::Director
  class Errand::LifecycleServiceStep
    def initialize(runner, deployment_planner, name, instance, logger)
      @runner = runner
      @deployment_planner = deployment_planner
      @name = name
      @instance = instance
      @logger = logger
    end

    def run(&checkpoint_block)
      @logger.info('Starting to run errand')
      result = @runner.run(@instance, &checkpoint_block)
      result.short_description(@name)
    ensure
      @deployment_planner.job_renderer.clean_cache!
    end

    def ignore_cancellation?
      false
    end
  end
end
