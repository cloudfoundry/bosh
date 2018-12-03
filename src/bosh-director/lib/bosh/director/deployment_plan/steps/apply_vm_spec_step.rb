require 'json'

module Bosh::Director
  module DeploymentPlan::Steps
    class ApplyVmSpecStep
      def initialize(instance_plan)
        @instance_plan = instance_plan
      end

      def perform(report)
        vm = report.vm
        spec = @instance_plan.spec
        agent_client = AgentClient.with_agent_id(vm.agent_id, 'unknown')

        # Agent will return dynamic network settings, we need to update spec with it
        # so that we can render templates with new spec later.
        agent_spec_keys = %w[networks deployment job index id]
        agent_partial_state = spec.as_apply_spec.select { |k, _| agent_spec_keys.include?(k) }
        agent_client.apply(agent_partial_state)

        instance_spec_keys = agent_spec_keys + %w[stemcell vm_type env update]
        instance_partial_state = spec.full_spec.select { |k, _| instance_spec_keys.include?(k) }

        agent_state = agent_client.get_state

        unless agent_state.nil?
          agent_networks = agent_state['networks']
          vm.network_spec = agent_networks
          vm.env_json = instance_partial_state['env'].to_json
          vm.cloud_properties_json = Hash(
            Hash(instance_partial_state['vm_type'])['cloud_properties'],
          ).to_json
          vm.stemcell_name = instance_partial_state['stemcell']['name']
          vm.stemcell_version = instance_partial_state['stemcell']['version']
          vm.save
          instance_partial_state['networks'] = agent_networks
        end

        @instance_plan.instance.add_state_to_model(instance_partial_state)
      end
    end
  end
end
