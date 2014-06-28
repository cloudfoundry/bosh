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
          pool.process do
            @event_log.track("#{instance.job.name}/#{instance.index}") do
              instance.apply_partial_vm_state
            end
          end
        end
      end
    end
  end
end
