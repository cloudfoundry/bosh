module Bosh::Director
  class DeploymentPlan::InstanceVmBinder
    def initialize(event_log)
      @event_log = event_log
    end

    # @param [Array<DeploymentPlan::Instance>]
    #   instances All instances to consider for binding to a VM
    def bind_instance_vms(instances)
      unbound_instances = []

      instances.each do |instance|
        # Don't allocate resource pool VMs to instances in detached state
        next if instance.state == 'detached'

        # Skip bound instances
        next if instance.model.vm

        unbound_instances << instance
      end

      return if unbound_instances.empty?

      @event_log.begin_stage('Binding instance VMs', unbound_instances.size)

      ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
        unbound_instances.each do |instance|
          pool.process { bind_instance_vm(instance) }
        end
      end
    end

    # @param [DeploymentPlan::Instance] instance
    def bind_instance_vm(instance)
      @event_log.track("#{instance.job.name}/#{instance.index}") do
        vm = instance.vm

        # Apply the assignment to the VM
        agent = AgentClient.with_defaults(vm.model.agent_id)
        state = vm.current_state
        state['job'] = instance.job.spec
        state['index'] = instance.index
        agent.apply(state)

        # Our assumption here is that director database access
        # is much less likely to fail than VM agent communication
        # so we only update database after we see a successful agent apply.
        # If database update fails subsequent deploy will try to
        # assign a new VM to this instance which is ok.
        vm.model.db.transaction do
          vm.model.update(:apply_spec => state)
          instance.model.update(:vm => vm.model)
        end

        instance.current_state = state
      end
    end
  end
end
