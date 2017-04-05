module Bosh::Director
  module DeploymentPlan
    class AgentStateMigrator
      def initialize(logger)
        @logger = logger
      end

      def get_state(instance)
        @logger.debug("Requesting current VM state for: #{instance.agent_id}")
        agent = AgentClient.with_vm_credentials_and_agent_id(instance.credentials, instance.agent_id)
        state = agent.get_state

        @logger.debug("Received VM state: #{state.pretty_inspect}")
        verify_state(instance, state)
        @logger.debug('Verified VM state')

        state.delete('release')
        if state.include?('job')
          state['job'].delete('release')
        end
        state
      end

      def verify_state(instance, state)
        unless state.kind_of?(Hash)
          @logger.error("Invalid state for '#{instance.vm_cid}': #{state.pretty_inspect}")
          raise AgentInvalidStateFormat,
            "VM '#{instance.vm_cid}' returns invalid state: " +
              "expected Hash, got #{state.class}"
        end
      end
    end
  end
end
