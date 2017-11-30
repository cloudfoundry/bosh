module Bosh::Director
  module DeploymentPlan
    module Steps
      class PrepareInstanceStep
        def initialize(instance_plan, use_active_vm: true)
          @instance_plan = instance_plan
          @use_active_vm = use_active_vm
        end

        def perform
          spec = InstanceSpec.create_from_instance_plan(@instance_plan)
          instance_model = @instance_plan.instance.model

          if @use_active_vm
            spec = spec.as_apply_spec
            agent_id = instance_model.agent_id
            raise 'no active VM available to prepare for instance' if agent_id.nil?
          else
            spec = spec.as_jobless_apply_spec
            vm = instance_model.most_recent_inactive_vm
            raise 'no inactive VM available to prepare for instance' if vm.nil?
            agent_id = vm.agent_id
          end

          AgentClient.with_agent_id(agent_id).prepare(spec)
        end
      end
    end
  end
end
