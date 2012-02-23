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

    # This converts the old agent response format to the new.  This can be taken
    # out once the agents never reply with the old message format again.
    # The old message format is just to pass the return object as JSON. That
    # means it could be any type -- array, hash, string, int, etc.
    # The new format is:
    # {"state"=>"task_state", "value"=><task_return_object>,
    #  "agent_task_id"=>123}
    # This is a class method to make testing easier.
    # @param [Object] msg The agent message to convert to the new format.
    # @return [Hash] The message in the new message format.
    def self.convert_old_message_to_new(msg)
      if msg && msg.is_a?(Hash)
        if !msg.has_key?("value")
          # There's no value but there is state and agent_task_id.
          # Just leave it.
          if msg.has_key?("state") && msg.has_key?("agent_task_id")
            return msg
          end
          # There's no value and either one or both of state/agent_task_id don't
          # exist.  Assume that the whole message response was meant to be the
          # value.
          return { "value" => msg,
                   "state" => msg["state"] || "done",
                   "agent_task_id" => msg["agent_task_id"] || nil }
        elsif !msg.has_key?("state")
          # The message has a value section, but no "state".  Mark state as
          # done.
          return { "value" => msg["value"],
                   "state" => "done",
                   "agent_task_id" => msg["agent_task_id"] || nil }
        else
          # The message was good from the start!
          return msg
        end
      end
      # If the message was anything other than a hash (float, int, string, array,
      # etc.) then we want to just make that be the "value".
      {"state" => "done", "value" => msg, "agent_task_id" => nil}
    end

    [:apply, :compile_package, :fetch_logs, :migrate_disk, :mount_disk,
     :unmount_disk, :drain].each do |method|
      define_method (method) do |*args|
        task = AgentClient.convert_old_message_to_new(super(*args))
        while task["state"] == "running"
          sleep(DEFAULT_POLL_INTERVAL)
          task = AgentClient.convert_old_message_to_new(get_task(task["agent_task_id"]))
        end
        task["value"]
      end
    end

  end
end
