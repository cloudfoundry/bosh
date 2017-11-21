module Bosh::Director
  module DeploymentPlan
    class VmSpecApplier
      def apply_initial_vm_state(spec, vm)
        agent_client = AgentClient.with_agent_id(vm.agent_id)

        # Agent will return dynamic network settings, we need to update spec with it
        # so that we can render templates with new spec later.
        agent_spec_keys = ['networks', 'deployment', 'job', 'index', 'id']
        agent_partial_state = spec.as_apply_spec.select {|k, _| agent_spec_keys.include?(k)}
        agent_client.apply(agent_partial_state)

        instance_spec_keys = agent_spec_keys + ['stemcell', 'vm_type', 'env']
        instance_partial_state = spec.full_spec.select {|k, _| instance_spec_keys.include?(k)}

        agent_state = agent_client.get_state
        unless agent_state.nil?
          agent_networks = agent_state['networks']
          vm.network_spec = agent_networks
          vm.save
          instance_partial_state['networks'] = agent_networks
        end

        instance_partial_state
      end
    end
  end
end
