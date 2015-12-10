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

        unless state.kind_of?(Hash)
          @logger.error("Invalid state for `#{vm_model.cid}': #{state.pretty_inspect}")
          raise AgentInvalidStateFormat,
            "VM `#{vm_model.cid}' returns invalid state: " +
              "expected Hash, got #{state.class}"
        end

        actual_job = state['job'].is_a?(Hash) ? state['job']['name'] : nil
        actual_index = state['index']

        if instance.nil? && !actual_job.nil?
          raise AgentUnexpectedJob,
            "VM `#{vm_model.cid}' is out of sync: " +
              "it reports itself as `#{actual_job}/#{actual_index}' but " +
              'there is no instance reference in DB'
        end
      end
    end
  end
end
