module Bosh::Director
  class Errand::LifecycleServiceStep
    def initialize(runner, instance, logger)
      @runner = runner
      @instance = instance
      @logger = logger
    end

    def prepare
    end

    def run(&checkpoint_block)
      @logger.info('Starting to run errand')
      result = @runner.run(@instance, &checkpoint_block)
      result.short_description
    end

    def ignore_cancellation?
      false
    end
  end
end
