module Bosh::Director
  class InstanceUpdater::NetworkUpdater
    def initialize(instance, vm_model, agent_client, resource_pool_updater, cloud, logger)
      @instance = instance
      @vm_model = vm_model
      @agent_client = agent_client
      @resource_pool_updater = resource_pool_updater
      @cloud = cloud
      @logger = logger
    end

    def update
      return unless @instance.networks_changed?

      network_settings = @instance.network_settings

      begin
        # If configure_networks can't configure the network as
        # requested, e.g. when the security groups change on AWS,
        # configure_networks() will raise an exception and we'll
        # recreate the VM to work around it
        @cloud.configure_networks(@vm_model.cid, network_settings)
      rescue Bosh::Clouds::NotSupported => e
        @logger.info("configure_networks not supported: #{e.message}")
        @instance.recreate = true
        @resource_pool_updater.update_resource_pool
        return
      end

      # Once CPI has configured the vm and stored the new network settings at the registry,
      # we restart the agent via a 'prepare_network_change' message in order for the agent
      # to pick up the new network settings.
      @agent_client.prepare_network_change(network_settings)

      # Give some time to the agent to restart before pinging if it's ready (race condition)
      sleep(5)

      @agent_client.wait_until_ready
    end
  end
end
