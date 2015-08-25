module Bosh::Director
  class DeploymentDeleter
    def initialize(event_log, logger, dns_manager, max_threads, dns_enabled)
      @event_log = event_log
      @logger = logger
      @dns_manager = dns_manager
      @max_threads = max_threads
      @dns_enabled = dns_enabled
    end

    def delete(deployment_plan, instance_deleter, vm_deleter)
      instances = deployment_plan.existing_instances.map do |instance_model|
        DeploymentPlan::InstanceFromDatabase.create_from_model(instance_model, @logger)
      end

      event_log_stage = @event_log.begin_stage('Deleting instances', instances.size)
      instance_deleter.delete_instances(instances, event_log_stage, max_threads: @max_threads)

      # For backwards compatibility for VMs that did not have instances
      deployment_model = deployment_plan.model
      deployment_model.reload
      delete_vms(vm_deleter, deployment_model.vms)

      @event_log.begin_stage('Removing deployment artifacts', 3)

      @event_log.track('Detaching stemcells') do
        @logger.info('Detaching stemcells')
        deployment_model.remove_all_stemcells
      end

      @event_log.track('Detaching releases') do
        @logger.info('Detaching releases')
        deployment_model.remove_all_release_versions
      end

      @event_log.begin_stage('Deleting properties', deployment_plan.model.properties.count)
      @logger.info('Deleting deployment properties')
      deployment_model.properties.each do |property|
        @event_log.track(property.name) do
          property.destroy
        end
      end

      @event_log.track('Deleting DNS records') do
        @logger.info('Deleting DNS records')
        @dns_manager.delete_dns_for_deployment(deployment_plan.name) if @dns_enabled
      end

      @event_log.track('Destroying deployment') do
        @logger.info('Destroying deployment')
        deployment_model.destroy
      end
    end

    private

    def delete_vms(vm_deleter, vms)
      ThreadPool.new(max_threads: @max_threads).wrap do |pool|
        @event_log.begin_stage('Deleting idle VMs', vms.count)

        vms.each do |vm|
          pool.process do
            @event_log.track("#{vm.cid}") do
              @logger.info("Deleting idle vm #{vm.cid}")
              vm_deleter.delete_vm(vm)
            end
          end
        end
      end
    end

  end
end
