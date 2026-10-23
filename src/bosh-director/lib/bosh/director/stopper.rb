module Bosh::Director
  class Stopper
    MAX_DRAIN_SECONDS = 3_600
    MAX_DRAIN_POLLS = 3_600

    class << self
      def stop(
        instance_plan:,
        target_state:,
        task: EventLog::NullTask.new,
        logger: Config.logger,
        intent: :keep_vm
      )
        instance_model = instance_plan.new? ? instance_plan.instance.model : instance_plan.existing_instance

        return if instance_model.compilation || instance_model.active_vm.nil? || instance_plan.unresponsive_agent?

        agent_client = AgentClient.with_agent_id(instance_model.agent_id, instance_model.name)

        if instance_plan.skip_drain
          logger.info("Skipping pre-stop and drain for '#{instance_model}'")
          task.advance(10, status: 'skipped pre-stop & drain')
        else
          logger.info("Running pre-stop for #{instance_model}")
          task.advance(5, status: 'executing pre-stop')
          agent_client.run_script('pre-stop', 'env' => pre_stop_env(intent))

          logger.info("Running drain for #{instance_model}")
          task.advance(5, status: 'executing drain')
          perform_drain(instance_plan, target_state, instance_model, agent_client, logger)
        end

        logger.info("Stopping instance #{instance_model}")
        task.advance(20, status: 'stopping jobs')
        agent_client.stop

        logger.info("Running post-stop for #{instance_model}")
        task.advance(10, status: 'executing post-stop')
        agent_client.run_script('post-stop', {})
      end

      private

      def pre_stop_env(intent)
        env = {
          'BOSH_VM_NEXT_STATE' => 'keep',
          'BOSH_INSTANCE_NEXT_STATE' => 'keep',
          'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
        }

        case intent
        when :delete_vm
          env['BOSH_VM_NEXT_STATE'] = 'delete'
        when :delete_instance
          env['BOSH_VM_NEXT_STATE'] = 'delete'
          env['BOSH_INSTANCE_NEXT_STATE'] = 'delete'
        when :delete_deployment
          env['BOSH_VM_NEXT_STATE'] = 'delete'
          env['BOSH_INSTANCE_NEXT_STATE'] = 'delete'
          env['BOSH_DEPLOYMENT_NEXT_STATE'] = 'delete'
        end

        env
      end

      def perform_drain(instance_plan, target_state, instance_model, agent_client, logger)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + MAX_DRAIN_SECONDS
        drain_type = needs_shutdown?(instance_plan, target_state) ? 'shutdown' : 'update'

        # Apply spec might change after shutdown drain (unlike update drain)
        # because instance's VM could be reconfigured.
        # Drain script can still capture intent from non-final apply spec.
        drain_apply_spec = instance_plan.spec.as_apply_spec
        drain_time = agent_client.drain(drain_type, drain_apply_spec)

        if drain_time.positive?
          interruptible_drain_sleep(drain_time, deadline)
        else
          wait_for_dynamic_drain(drain_time, instance_model, agent_client, logger, deadline)
        end
      end

      def interruptible_drain_sleep(seconds, deadline)
        unless seconds.finite? && seconds >= 0 && seconds <= MAX_DRAIN_SECONDS
          raise DirectorError, 'Drain exceeded the supported wait budget'
        end
        remaining = seconds
        while remaining.positive?
          Config.job_cancelled?
          time_left = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          raise DirectorError, 'Drain exceeded the supported wait budget' unless time_left.positive?

          interval = [remaining, time_left, 1].min
          sleep(interval)
          remaining -= interval
        end
      end

      def needs_shutdown?(instance_plan, target_state)
        target_state == Bosh::Director::INSTANCE_STATE_STOPPED ||
          target_state == Bosh::Director::INSTANCE_STATE_DETACHED ||
          instance_plan.needs_shutting_down? ||
          instance_plan.persistent_disk_changed?
      end

      def wait_for_dynamic_drain(initial_drain_time, instance_model, agent_client, logger, deadline)
        drain_time = initial_drain_time

        polls = 0
        loop do
          Config.job_cancelled?
          polls += 1
          if polls > MAX_DRAIN_POLLS || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
            raise DirectorError, 'Drain exceeded the supported wait budget'
          end
          wait_time = drain_time.abs
          if wait_time.positive?
            logger.info("'#{instance_model}' is draining: checking back in #{wait_time}s")
            interruptible_drain_sleep(wait_time, deadline)
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
end
