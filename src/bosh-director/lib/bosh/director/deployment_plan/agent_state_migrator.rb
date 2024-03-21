require 'pp' # for #pretty_inspect

module Bosh::Director
  module DeploymentPlan
    class AgentStateMigrator
      def initialize(logger)
        @logger = logger
      end

      def get_state(instance, ignore_unresponsive_agent)
        @logger.debug("Requesting current VM state for: #{instance.agent_id}")
        agent = AgentClient.with_agent_id(instance.agent_id, instance.name)

        begin
          state = agent.get_state { Config.job_cancelled? }
        rescue Bosh::Director::RpcTimeout, Bosh::Director::RpcRemoteException => e
          raise e, "#{instance.name}: #{e.message}" unless ignore_unresponsive_agent

          @logger.debug("Unresponsive agent requesting VM state for: #{instance.agent_id}")
          return { 'job_state' => 'unresponsive' }
        end

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
