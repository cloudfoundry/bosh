module Bosh::Director
  module Api
    class EventManager
    include SyslogHelper

      def initialize(record_events)
        @record_events = record_events
      end

      def event_to_hash(event)
        {
            'id' => event.id.to_s,
            'parent_id' => event.parent_id.to_s,
            'timestamp' => event.timestamp.to_i,
            'user' => event.user,
            'action' => event.action,
            'object_type' => event.object_type,
            'object_name' => event.object_name,
            'error' => event.error,
            'task' => event.task,
            'deployment' => event.deployment,
            'instance' => event.instance,
            'context' => event.context
        }.reject { |k, v| v.nil? || v == '' }
      end

      def create_event(options)
        unless @record_events
          return Models::Event.new
        end
        parent_id   = options.fetch(:parent_id, nil)
        timestamp   = options.fetch(:timestamp, Time.now)
        user        = options[:user]
        action      = options[:action]
        object_type = options[:object_type]
        object_name = options.fetch(:object_name, nil)
        task        = options.fetch(:task, nil)
        error       = options.fetch(:error, nil)
        deployment  = options.fetch(:deployment, nil)
        instance    = options.fetch(:instance, nil)
        context     = options.fetch(:context, {})

        event = Models::Event.create(
            parent_id:   parent_id,
            timestamp:   timestamp,
            user:        user,
            action:      action,
            object_type: object_type,
            object_name: object_name,
            error:       error ? error.to_s : nil,
            task:        task,
            deployment:  deployment,
            instance:    instance,
            context:     context)
        syslog(:info, JSON.generate(event.to_hash))
        event
      end

      def remove_old_events (max_events = 10000)
        if Bosh::Director::Models::Event.count > max_events
          last_id = Bosh::Director::Models::Event.
              order { Sequel.desc(:id) }.limit(1, max_events).first.id
          last_parent_id = Bosh::Director::Models::Event.
              order { Sequel.desc(:id) }.limit(max_events).min(:parent_id)
          start_id_to_remove = (last_parent_id.nil? || (last_parent_id > last_id)) ? last_id+1: last_parent_id

          Bosh::Director::Models::Event.filter(Sequel.lit("id < ?", start_id_to_remove)).delete if start_id_to_remove != 0
        end
      end
    end
  end
end
