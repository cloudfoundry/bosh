module Bosh::Director
  class AgentClient < Client

    def initialize(*args)
      # retry 'get_state' and 'get_task' in case of timeout errors
      options = {:retry_methods => {:get_state => 10, :get_task => 10}}
      super("agent", *args, options)
    end

  end
end
