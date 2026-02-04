module Bosh::Director
  class Stopper
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
        drain_type = needs_shutdown?(instance_plan, target_state) ? 'shutdown' : 'update'

        # Apply spec might change after shutdown drain (unlike update drain)
        # because instance's VM could be reconfigured.
        # Drain script can still capture intent from non-final apply spec.
        drain_apply_spec = instance_plan.spec.as_apply_spec
        drain_time = agent_client.drain(drain_type, drain_apply_spec)

        if drain_time.positive?
          sleep(drain_time)
        else
          wait_for_dynamic_drain(drain_time, instance_model, agent_client, logger)
        end
      end

      def needs_shutdown?(instance_plan, target_state)
        target_state == Bosh::Director::INSTANCE_STATE_STOPPED ||
          target_state == Bosh::Director::INSTANCE_STATE_DETACHED ||
          instance_plan.needs_shutting_down? ||
          instance_plan.persistent_disk_changed?
      end

      def wait_for_dynamic_drain(initial_drain_time, instance_model, agent_client, logger)
        drain_time = initial_drain_time

        loop do
          wait_time = drain_time.abs
          if wait_time.positive?
            logger.info("'#{instance_model}' is draining: checking back in #{wait_time}s")
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
end
