# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class AgentClient < Client

    DEFAULT_POLL_INTERVAL = 1.0

    def initialize(id, options = {})
      # Retry 'get_state' and 'get_task' in case of timeout errors
      defaults = {
        :retry_methods => { :get_state => 2, :get_task => 2}
      }

      super("agent", id, defaults.merge(options))
    end

    [:apply, :compile_package, :fetch_logs, :migrate_disk, :mount_disk, :unmount_disk].each do |method|
      define_method (method) do |*args|
        task = super(*args)
        while task["state"] == "running"
          sleep(DEFAULT_POLL_INTERVAL)
          task = get_task(task["agent_task_id"])
        end
        task
      end
    end

  end
end
