module Bosh::Director
  module DeploymentPlan
    class AgentStateMigrator
      def initialize(deployment_plan, logger)
        @deployment_plan = deployment_plan
        @logger = logger
      end

      def get_state(vm_model)
        @logger.debug("Requesting current VM state for: #{vm_model.agent_id}")
        agent = AgentClient.with_vm(vm_model)
        state = agent.get_state

        @logger.debug("Received VM state: #{state.pretty_inspect}")
        verify_state(vm_model, state)
        @logger.debug('Verified VM state')

        state.delete('release')
        if state.include?('job')
          state['job'].delete('release')
        end
        state
      end

      def verify_state(vm_model, state)
        instance = vm_model.instance

        if instance && instance.deployment_id != vm_model.deployment_id
          # Both VM and instance should reference same deployment
          raise VmInstanceOutOfSync,
            "VM `#{vm_model.cid}' and instance " +
              "`#{instance.job}/#{instance.index}' " +
              "don't belong to the same deployment"
        end

        unless state.kind_of?(Hash)
          @logger.error("Invalid state for `#{vm_model.cid}': #{state.pretty_inspect}")
          raise AgentInvalidStateFormat,
            "VM `#{vm_model.cid}' returns invalid state: " +
              "expected Hash, got #{state.class}"
        end

        actual_deployment_name = state['deployment']
        expected_deployment_name = @deployment_plan.name

        if actual_deployment_name != expected_deployment_name
          raise AgentWrongDeployment,
            "VM `#{vm_model.cid}' is out of sync: " +
              'expected to be a part of deployment ' +
              "`#{expected_deployment_name}' " +
              'but is actually a part of deployment ' +
              "`#{actual_deployment_name}'"
        end

        actual_job = state['job'].is_a?(Hash) ? state['job']['name'] : nil
        actual_index = state['index']

        if instance.nil? && !actual_job.nil?
          raise AgentUnexpectedJob,
            "VM `#{vm_model.cid}' is out of sync: " +
              "it reports itself as `#{actual_job}/#{actual_index}' but " +
              'there is no instance reference in DB'
        end

        if instance &&
          (instance.job != actual_job || instance.index != actual_index)
          # Check if we are resuming a previously unfinished rename
          if actual_job == @deployment_plan.job_rename['old_name'] &&
            instance.job == @deployment_plan.job_rename['new_name'] &&
            instance.index == actual_index

            # Rename already happened in the DB but then something happened
            # and agent has never been updated.
            unless @deployment_plan.job_rename['force']
              raise AgentRenameInProgress,
                "Found a job `#{actual_job}' that seems to be " +
                  "in the middle of a rename to `#{instance.job}'. " +
                  "Run 'rename' again with '--force' to proceed."
            end
          else
            raise AgentJobMismatch,
              "VM `#{vm_model.cid}' is out of sync: " +
                "it reports itself as `#{actual_job}/#{actual_index}' but " +
                "according to DB it is `#{instance.job}/#{instance.index}'"
          end
        end
      end
    end
  end
end
