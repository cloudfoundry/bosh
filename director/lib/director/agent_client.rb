module Bosh::Director
  class AgentClient < Client

    DEFAULT_POLL_INTERVAL = 1.0

    def initialize(id, options = {})
      # retry 'get_state' and 'get_task' in case of timeout errors
      defaults = {
        :retry_methods => { :get_state => 2, :get_task => 2}
      }

      super("agent", id, defaults.merge(options))
    end

    def run_task(method, *args)
      task = send(method, *args)

      while task["state"] == "running"
        sleep(DEFAULT_POLL_INTERVAL)
        task = get_task(task["agent_task_id"])
      end
    end

  end
end
