require 'bosh/director/agent_message_converter'

module Bosh::Director
  class AgentClient < Client
    def initialize(id, options = {})
      defaults = {
        retry_methods: { # in case of timeout errors
                         get_state: 2,
                         get_task: 2,
        }
      }

      credentials = Bosh::Director::Models::Vm.find(:agent_id => id).credentials
      if credentials
        defaults.merge!(credentials: credentials)
      end

      super('agent', id, defaults.merge(options))
    end
  end
end
