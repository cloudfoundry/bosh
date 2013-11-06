require 'bosh/director/agent_message_converter'

module Bosh::Director
  class AgentClient < Client

    DEFAULT_POLL_INTERVAL = 1.0

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

    [
      :prepare,
      :apply,
      :compile_package,
      :drain,
      :fetch_logs,
      :migrate_disk,
      :mount_disk,
      :stop,
      :unmount_disk,
    ].each do |method_name|
      define_method (method_name) do |*args|
        task = AgentMessageConverter.convert_old_message_to_new(super(*args))
        while task['state'] == 'running'
          sleep(DEFAULT_POLL_INTERVAL)
          task = AgentMessageConverter.convert_old_message_to_new(get_task(task['agent_task_id']))
        end
        task['value']
      end
    end
  end
end
