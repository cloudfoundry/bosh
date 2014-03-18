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
      @cloud.configure_networks(@vm_model.cid, network_settings)
      configure_existing_vm(network_settings)

    rescue Bosh::Clouds::NotSupported => e
      # If configure_networks can't configure the network as
      # requested, e.g. when the security groups change on AWS,
      # configure_networks() will raise an exception and we'll
      # recreate the VM to work around it
      @logger.info("configure_networks not supported: #{e.message}")
      configure_new_vm
    end

    private

    def configure_existing_vm(network_settings)
      # Some CPIs might power off and then power on vm to reconfigure network adapters,
      # so Director needs to wait for agent to become responsive
      @agent_client.wait_until_ready

      # Once CPI has configured the vm and stored the new network settings at the registry,
      # we restart the agent via a 'prepare_network_change' message in order for the agent
      # to pick up the new network settings.
      @agent_client.prepare_network_change(network_settings)

      # Since current implementation of prepare_network_change is to kill the agent
      # we need to wait until the agent is ready. However, we want to avoid
      # talking to the old agent, so we need to wait for it to die.
      sleep(5)

      @agent_client.wait_until_ready
    end

    def configure_new_vm
      @instance.recreate = true
      @resource_pool_updater.update_resource_pool
    end
  end
end
