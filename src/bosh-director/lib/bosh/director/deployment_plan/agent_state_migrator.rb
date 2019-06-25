module Bosh::Director
  module DeploymentPlan
    class AgentStateMigrator
      def initialize(logger)
        @logger = logger
      end

      def get_state(instance)
        @logger.debug("Requesting current VM state for: #{instance.agent_id}")
        agent = AgentClient.with_agent_id(instance.agent_id, instance.name)
        state = agent.get_state { Config.job_cancelled? }

        @logger.debug("Received VM state: #{state.pretty_inspect}")
        verify_state(instance, state)
        @logger.debug('Verified VM state')

        state.delete('release')
        state['job'].delete('release') if state.include?('job')
        state
      end

      def verify_state(instance, state)
        return if state.is_a?(Hash)

        @logger.error("Invalid state for '#{instance.vm_cid}': #{state.pretty_inspect}")
        raise AgentInvalidStateFormat,
              "VM '#{instance.vm_cid}' returns invalid state: " \
              "expected Hash, got #{state.class}"
      end
    end
  end
end
