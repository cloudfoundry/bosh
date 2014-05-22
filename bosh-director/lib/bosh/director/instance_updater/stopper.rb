module Bosh::Director
  class InstanceUpdater::Stopper
    def initialize(instance, agent_client, target_state, config, logger)
      @instance = instance
      @agent_client = agent_client
      @target_state = target_state
      @config = config
      @logger = logger
    end

    def stop
      drain_time = if shutting_down?
        @agent_client.drain('shutdown')
      else
        @agent_client.drain('update', @instance.spec)
      end

      if drain_time > 0
        sleep(drain_time)
      else
        wait_for_dynamic_drain(drain_time)
      end

      @agent_client.stop
    end

    private

    def shutting_down?
      @instance.resource_pool_changed? ||
        @instance.persistent_disk_changed? ||
        @instance.networks_changed? ||
        @target_state == 'stopped' ||
        @target_state == 'detached'
    end

    def wait_for_dynamic_drain(initial_drain_time)
      drain_time = initial_drain_time

      loop do
        # This could go on forever if drain script is broken, canceling the task is a way out.
        @config.task_checkpoint

        wait_time = drain_time.abs
        if wait_time > 0
          @logger.info("`#{@instance}' is draining: checking back in #{wait_time}s")
          sleep(wait_time)
        end

        # Positive number always means last drain call:
        break if drain_time >= 0

        # We used to ignore exceptions from drain status for compatibility
        # with older agents but it doesn't need to happen anymore, as
        # realistically speaking, all agents have already been updated
        # to support drain status mechanism and swallowing real errors
        # would be bad here, as it could mask potential problems.
        drain_time = @agent_client.drain('status')
      end
    end
  end
end
