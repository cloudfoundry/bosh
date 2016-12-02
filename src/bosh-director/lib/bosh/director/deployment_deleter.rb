module Bosh::Director
  class DeploymentDeleter
    def initialize(event_log, logger, dns_manager, max_threads)
      @event_log = event_log
      @logger = logger
      @dns_manager = dns_manager
      @max_threads = max_threads
    end

    def delete(deployment_model, instance_deleter, vm_deleter)
      instance_plans = deployment_model.instances.map do |instance_model|
        DeploymentPlan::InstancePlan.new(
          existing_instance: instance_model,
          instance: nil,
          desired_instance: nil,
          network_plans: []
        )
      end
      event_log_stage = @event_log.begin_stage('Deleting instances', instance_plans.size)
      instance_deleter.delete_instance_plans(instance_plans, event_log_stage, max_threads: @max_threads)

      event_log_stage = @event_log.begin_stage('Removing deployment artifacts', 3)

      event_log_stage.advance_and_track('Detaching stemcells') do
        @logger.info('Detaching stemcells')
        deployment_model.remove_all_stemcells
      end

      event_log_stage.advance_and_track('Detaching releases') do
        @logger.info('Detaching releases')
        deployment_model.remove_all_release_versions
      end

      event_log_stage = @event_log.begin_stage('Deleting properties', deployment_model.properties.count)
      @logger.info('Deleting deployment properties')
      deployment_model.properties.each do |property|
        event_log_stage.advance_and_track(property.name) do
          property.destroy
        end
      end

      event_log_stage.advance_and_track('Destroying deployment') do
        @logger.info('Destroying deployment')
        deployment_model.destroy
      end
    end
  end
end
