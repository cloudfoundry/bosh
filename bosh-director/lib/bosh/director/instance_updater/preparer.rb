module Bosh::Director
  class InstanceUpdater::Preparer
    def initialize(instance, agent_client)
      @instance = instance
      @agent_client = agent_client
    end

    def prepare
      @agent_client.prepare(@instance.spec) unless detached?
    rescue RpcRemoteException => e
      raise unless e.message =~ /unknown message/
    end

    private

    def detached?
      @instance.state == 'detached'
    end
  end
end
