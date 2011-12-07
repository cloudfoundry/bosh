module Bosh::Director
  class AgentClient < Client

    def initialize(id, options = {})
      # retry 'get_state' and 'get_task' in case of timeout errors
      defaults = {
        :retry_methods => { :get_state => 2, :get_task => 2}
      }

      super("agent", id, defaults.merge(options))
    end

  end
end
