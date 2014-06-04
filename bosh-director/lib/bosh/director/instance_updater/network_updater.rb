module Bosh::Director
  class InstanceUpdater::NetworkUpdater
    def initialize(instance, vm_model, agent_client, vm_updater, cloud, logger)
      @instance = instance
      @vm_model = vm_model
      @agent_client = agent_client
      @vm_updater = vm_updater
      @cloud = cloud
      @logger = logger
    end

    def update
      unless @instance.networks_changed?
        @logger.info('Skipping network re-configuration')
        return [@vm_model, @agent_client]
      end

      network_settings = @instance.network_settings

      strategies = [
        ConfigureNetworksStrategy.new(@agent_client, network_settings, @logger),
        PrepareNetworkChangeStrategy.new(@agent_client, network_settings, @logger),
      ]

      @logger.info("Planning to reconfigure network with settings: #{network_settings}")
      selected_strategy = strategies.find { |s| s.before_configure_networks }

      @cloud.configure_networks(@vm_model.cid, network_settings)

      selected_strategy.after_configure_networks

      [@vm_model, @agent_client]

    rescue Bosh::Clouds::NotSupported => e
      @logger.info("Failed reconfiguring existing VM: #{e.inspect}")

      # If configure_networks CPI method cannot reconfigure VM networking
      # (e.g. when the security groups change on AWS)
      # it raises Bosh::Clouds::NotSupported to indicate new VM is needed.
      @logger.info('Creating VM with new network configurations')
      @instance.recreate = true
      @vm_updater.update(nil)
    end

    private

    # Newer agents support prepare_configure_networks/configure_networks messages
    class ConfigureNetworksStrategy
      def initialize(agent_client, network_settings, logger)
        @agent_client = agent_client
        @network_settings = network_settings
        @logger = logger
      end

      def before_configure_networks
        @agent_client.prepare_configure_networks(@network_settings)
        true
      rescue RpcRemoteException => e
        @logger.info("Agent returned error from prepare_configure_networks: #{e.inspect}")
        raise unless e.message =~ /unknown message/
        false
      end

      def after_configure_networks
        # Some CPIs might power off and then power on vm to reconfigure network adapters,
        # so Director needs to wait for agent to become responsive
        @logger.info('Waiting for agent to become responsive')
        @agent_client.wait_until_ready

        # Agent's configure_networks is a long running task
        # hence we do not need to wait_until_ready after it
        @agent_client.configure_networks(@network_settings)
      end
    end

    # Older agents only support prepare_network_change
    class PrepareNetworkChangeStrategy
      def initialize(agent_client, network_settings, logger)
        @agent_client = agent_client
        @network_settings = network_settings
        @logger = logger
      end

      def before_configure_networks
        true
      end

      def after_configure_networks
        # Some CPIs might power off and then power on vm to reconfigure network adapters,
        # so Director needs to wait for agent to become responsive
        @logger.info('Waiting for agent to become responsive')
        @agent_client.wait_until_ready

        # Once CPI has configured the vm and stored the new network settings at the registry,
        # we restart the agent via a 'prepare_network_change' message in order for the agent
        # to pick up the new network settings.
        @agent_client.prepare_network_change(@network_settings)

        # Since current implementation of prepare_network_change is to kill the agent
        # we need to wait until the agent is ready. However, we want to avoid
        # talking to the old agent, so we need to wait for it to die.
        @logger.info('Sleeping after prepare_network_change message')
        sleep(5)

        @logger.info('Waiting for agent to become responsive')
        @agent_client.wait_until_ready
      end
    end
  end
end
