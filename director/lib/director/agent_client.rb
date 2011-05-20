module Bosh::Director
  class AgentClient < Client

    def initialize(id)
      # retry 'get_state' and 'get_task' in case of timeout errors
      options = {:retry_methods => {:get_state => 10, :get_task => 10}}
      super("agent", id, options)
    end

  end
end
