require 'bosh/director'

module Bosh::Director
  class InstancePreparer
    def initialize(instance, agent_client)
      @instance = instance
      @agent_client = agent_client
    end

    def prepare
      unless @instance.state == 'detached'
        @agent_client.prepare(@instance.spec)
      end
    end
  end
end
