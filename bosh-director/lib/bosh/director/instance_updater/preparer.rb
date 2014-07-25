module Bosh::Director
  class InstanceUpdater::Preparer
    def initialize(instance, agent_client, logger)
      @instance = instance
      @agent_client = agent_client
      @logger = logger
    end

    def prepare
      # If resource pool has changed or instance will be detached
      # there is no point in preparing current VM for future since it will be destroyed.
      if !@instance.resource_pool_changed? && @instance.state != 'detached'
        @agent_client.prepare(@instance.spec)
      end
    rescue RpcRemoteException => e
      if e.message =~ /unknown message/
        # It's ok if agent does not support prepare optimization
        @logger.warn("Ignoring prepare 'unknown message' error from the agent: #{e.inspect}")
      else
        # Prepare is really an optimization to a deployment process.
        # It should not prevent deploy from continuing on and trying to actually finish an update.
        @logger.warn("Ignoring prepare error from the agent: #{e.inspect}")
      end
    end
  end
end
