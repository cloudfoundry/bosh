module Bosh::Director
  class DeploymentDeleter
    include LockHelper
    def initialize(event_log, logger, powerdns_manager, max_threads)
      @event_log = event_log
      @logger = logger
      @powerdns_manager = powerdns_manager
      @max_threads = max_threads
      @variables_interpolator = ConfigServer::VariablesInterpolator.new
    end

    def delete(deployment_model, instance_deleter, vm_deleter)
      instance_plans = deployment_model.instances.map do |instance_model|
        DeploymentPlan::InstancePlan.new(
          existing_instance: instance_model,
          instance: nil,
          desired_instance: nil,
          network_plans: [],
          variables_interpolator: @variables_interpolator
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

      if Config.network_lifecycle_enabled?
        deployment_model.networks.each do |network|
          with_network_lock(network.name) do
            if network.deployments.size == 1
              OrphanNetworkManager.new(Config.logger).orphan_network(network)
            end

            remove_unused_subnets(deployment_model, network)
          end
        end
      end

      event_log_stage.advance_and_track('Destroying deployment') do
        @logger.info('Destroying deployment')
        deployment_model.destroy
      end
    end

    private

    def unused_subnets(new_subnets, old_subnets)
      old_subnets.select do |subnet|
        new_subnets.find { |e| e['name'] == subnet.name }.nil?
      end
    end

    def latest_cloud_config(deployment)
      Models::Config.latest_set_for_teams('cloud', *deployment.teams).max(&:id).raw_manifest
    end

    def used_cloud_config_state(deployment)
      latest = Models::Config.latest_set_for_teams('cloud', *deployment.teams).map(&:id).sort
      if deployment.cloud_configs.empty?
        'none'
      elsif deployment.cloud_configs.map(&:id).sort == latest
        'latest'
      else
        'outdated'
      end
    end

    def delete_subnet(cloud_factory, subnet)
      cpi = cloud_factory.get(subnet.cpi)
      begin
        @logger.info("deleting unused subnet #{subnet.name}")
        cpi.delete_network(subnet.cid)
      rescue StandardError => e
        @logger.error("failed to delete subnet #{subnet.name}: #{e.message}")
      end

      subnet.destroy
    end

    def remove_unused_subnets(deployment_model, network)
      other_deployments = network.deployments.delete_if { |x| x == deployment_model }
      return if other_deployments.empty?
      return unless other_deployments.all? { |deployment| used_cloud_config_state(deployment) == 'latest' }
      cloud_config_hash = latest_cloud_config(other_deployments.first)
      network_spec = cloud_config_hash['networks'].find { |x| x['name'] == network.name }
      unused_subnets(network_spec['subnets'], network.subnets).each do |subnet|
        cloud_factory = AZCloudFactory.create_with_latest_configs(deployment_model)
        delete_subnet(cloud_factory, subnet)
      end
    end
  end
end
