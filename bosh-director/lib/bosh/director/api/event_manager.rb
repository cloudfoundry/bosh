module Bosh::Director
  module Api
    class EventManager

      def event_to_hash(event)
        {
            "id"          => event.id.to_s,
            "parent_id"   => event.parent_id.to_s,
            "timestamp"   => event.timestamp.to_i,
            "user"        => event.user,
            "action"      => event.action,
            "object_type" => event.object_type,
            "object_name" => event.object_name,
            "error"       => event.error,
            "task"        => event.task,
            "deployment"  => event.deployment,
            "instance"    => event.instance,
            "context"     => event.context
        }.reject { |k, v| v.nil? || v == "" }
      end

      def create_event(options)
        parent_id   = options.fetch(:parent_id, nil)
        user        = options[:user]
        action      = options[:action]
        object_type = options[:object_type]
        object_name = options[:object_name]
        task        = options.fetch(:task, nil)
        error       = options.fetch(:error, nil)
        deployment  = options.fetch(:deployment, nil)
        instance    = options.fetch(:instance, nil)
        context     = options.fetch(:context, {})

        Models::Event.create(
            parent_id:   parent_id,
            timestamp:   Time.now,
            user:        user,
            action:      action,
            object_type: object_type,
            object_name: object_name,
            error:       error,
            task:        task,
            deployment:  deployment,
            instance:    instance,
            context:     context)
      end
    end
  end
end
