require 'bosh/director/agent_message_converter'

module Bosh::Director
  class AgentClient < Client
    def self.with_defaults(id, options = {})
      defaults = {
        retry_methods: { # in case of timeout errors
                         get_state: 2,
                         get_task: 2,
        }
      }

      credentials = Bosh::Director::Models::Vm.find(:agent_id => id).credentials
      defaults.merge!(credentials: credentials) if credentials

      Client.new('agent', id, defaults.merge(options))
    end
  end
end
