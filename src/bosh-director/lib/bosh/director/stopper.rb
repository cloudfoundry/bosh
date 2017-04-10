module Bosh::Director
  class Stopper
    def initialize(instance_plan, target_state, config, logger)
      @instance_plan = instance_plan
      @instance_model = @instance_plan.new? ? instance_plan.instance.model : instance_plan.existing_instance
      @target_state = target_state
      @config = config
      @logger = logger
    end

    def stop
      return if @instance_model.compilation || @instance_model.active_vm.nil? || @instance_plan.needs_to_fix?

      if @instance_plan.skip_drain
        @logger.info("Skipping drain for '#{@instance_model}'")
      else
        perform_drain
      end

      agent_client.stop
    end

    private

    def agent_client
      @agent_client ||= AgentClient.with_vm_credentials_and_agent_id(@instance_model.credentials, @instance_model.agent_id)
    end

    def perform_drain
      drain_type = needs_drain_to_migrate_data? ? 'shutdown' : 'update'

      # Apply spec might change after shutdown drain (unlike update drain)
      # because instance's VM could be reconfigured.
      # Drain script can still capture intent from non-final apply spec.
      drain_apply_spec = @instance_plan.spec.as_apply_spec
      drain_time = agent_client.drain(drain_type, drain_apply_spec)

      if drain_time > 0
        sleep(drain_time)
      else
        wait_for_dynamic_drain(drain_time)
      end
    end

    def needs_drain_to_migrate_data?
      @target_state == 'stopped' ||
        @target_state == 'detached' ||
        @instance_plan.needs_shutting_down? ||
        @instance_plan.persistent_disk_changed?
    end

    def wait_for_dynamic_drain(initial_drain_time)
      drain_time = initial_drain_time

      loop do
        wait_time = drain_time.abs
        if wait_time > 0
          @logger.info("'#{@instance_model}' is draining: checking back in #{wait_time}s")
          sleep(wait_time)
        end

        # Positive number always means last drain call:
        break if drain_time >= 0

        # We used to ignore exceptions from drain status for compatibility
        # with older agents but it doesn't need to happen anymore, as
        # realistically speaking, all agents have already been updated
        # to support drain status mechanism and swallowing real errors
        # would be bad here, as it could mask potential problems.
        drain_time = agent_client.drain('status')
      end
    end
  end
end
