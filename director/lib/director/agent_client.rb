module Bosh::Director
  class AgentClient < Client

    def initialize(id, options = {})
      # retry 'get_state' and 'get_task' in case of timeout errors
      r = {:retry_methods => {:get_state => 10, :get_task => 10}}
      super("agent", id, options.merge(r))
    end

  end
end
