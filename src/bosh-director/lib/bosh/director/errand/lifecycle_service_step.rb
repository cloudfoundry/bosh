module Bosh::Director
  class Errand::LifecycleServiceStep
    def initialize(runner, name, instance, logger)
      @runner = runner
      @name = name
      @instance = instance
      @logger = logger
    end

    def prepare
    end

    def run(&checkpoint_block)
      @logger.info('Starting to run errand')
      result = @runner.run(@instance, &checkpoint_block)
      result.short_description(@name)
    end

    def ignore_cancellation?
      false
    end
  end
end
