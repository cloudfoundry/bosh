module Bosh::Director
  class InstanceUpdater::StateApplier
    def initialize(instance_plan, agent_client, rendered_job_templates_cleaner)
      @instance_plan = instance_plan
      @instance = @instance_plan.instance
      @agent_client = agent_client
      @rendered_job_templates_cleaner = rendered_job_templates_cleaner
    end

    def apply
      @instance.apply_vm_state(@instance_plan.spec)
      @instance.update_templates(@instance_plan.templates)
      @rendered_job_templates_cleaner.clean

      if @instance.state == 'started'
        @agent_client.run_script('pre-start', {})
        @agent_client.start
      end
    end
  end
end
