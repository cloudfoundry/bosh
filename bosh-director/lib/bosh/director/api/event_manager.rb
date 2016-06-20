module Bosh::Director
  module Api
    class EventManager
      def initialize(record_events)
        @record_events = record_events
      end

      def event_to_hash(event)
        {
            'id' => event.id.to_f.to_s,
            'parent_id' => event.parent_id.to_f.to_s,
            'timestamp' => event.id.to_i,
            'user' => event.user,
            'action' => event.action,
            'object_type' => event.object_type,
            'object_name' => event.object_name,
            'error' => event.error,
            'task' => event.task,
            'deployment' => event.deployment,
            'instance' => event.instance,
            'context' => event.context
        }.reject { |k, v| v.nil? || v == ''|| v == '0.0' }
      end

      def create_event(options)
        unless @record_events
          return Models::Event.new
        end

        parent_id   = options.fetch(:parent_id, nil)
        user        = options[:user]
        action      = options[:action]
        object_type = options[:object_type]
        object_name = options.fetch(:object_name, nil)
        task        = options.fetch(:task, nil)
        error       = options.fetch(:error, nil)
        deployment  = options.fetch(:deployment, nil)
        instance    = options.fetch(:instance, nil)
        context     = options.fetch(:context, {})

        event = Models::Event.new(
            parent_id:   parent_id,
            user:        user,
            action:      action,
            object_type: object_type,
            object_name: object_name,
            error:       error ? error.to_s : nil,
            task:        task,
            deployment:  deployment,
            instance:    instance,
            context:     context)
        save_event(event)
        event
      end

      def remove_old_events (max_events = 10000)
        if Bosh::Director::Models::Event.count > max_events
          events = Bosh::Director::Models::Event.
              order { Sequel.desc(:id) }.limit(max_events)
          last_id = events.all.last.id
          last_parent = events.exclude(:parent_id => nil).order { Sequel.asc(:parent_id) }.first
          start_id_to_remove = (last_parent.nil? || (last_parent.parent_id > last_id)) ? last_id : last_parent.parent_id

          Bosh::Director::Models::Event.filter("id < ?", Time.at(start_id_to_remove)).delete if start_id_to_remove
        end
      end

      private
      def save_event(event)
        Bosh::Common.retryable(sleep: 0.000001, tries: 10, on: [Sequel::ValidationFailed, Sequel::DatabaseError], matching: /unique|duplicate/i) do |attempt|
          event.id = event.id + 0.000001 if attempt > 1
          event.save
          true
        end
      end
    end
  end
end
