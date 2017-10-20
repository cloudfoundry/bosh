require 'bosh/director/api/controllers/base_controller'
require 'time'

module Bosh::Director
  module Api::Controllers
    class EventsController < BaseController
      EVENT_LIMIT = 200

      get '/:id' do
        content_type(:json)

        event_id = params[:id].to_i
        event = Models::Event[event_id]
        if event.nil?
          not_found
        end
        json_encode(@event_manager.event_to_hash(event))
      end

      get '/', scope: :read_events do
        content_type(:json)

        events = Models::Event.order_by(Sequel.desc(:id))

        if params['before_id']
          before_id = params['before_id'].to_i
          events = events.filter("id < ?", before_id)
        end

        if params['before_time']
          begin
            before_datetime = timestamp_filter_value(params['before_time'])
          rescue ArgumentError
            status(400)
            body("Invalid before parameter: '#{params['before_time']}' ")
            return
          end
          events = events.filter("timestamp < ?", before_datetime)
        end

        if params['after_time']
          begin
            after_datetime = timestamp_filter_value(params['after_time']) + 1
          rescue ArgumentError
            status(400)
            body("Invalid after parameter: '#{params['after_time']}' ")
            return
          end
          events = events.filter("timestamp >= ?", after_datetime)
        end

        if params['task']
          events = events.where(task: params['task'])
        end

        if params['deployment']
          events = events.where(deployment: params['deployment'])
        end

        if params['instance']
          events = events.where(instance: params['instance'])
        end

        if params['user']
          events = events.where(user: params['user'])
        end

        if params['action']
          events = events.where(action: params['action'])
        end

        if params['object_type']
          events = events.where(object_type: params['object_type'])
        end

        if params['object_name']
          events = events.where(object_name: params['object_name'])
        end

        events = events.limit(EVENT_LIMIT).map do |event|
          @event_manager.event_to_hash(event)
        end
        json_encode(events)
      end

      post '/', :consumes => [:json] do
        @permission_authorizer.granted_or_raise(:director, :admin, token_scopes)
        payload = json_decode(request.body.read)
        raise ValidationInvalidType, 'Action, object_type, object_name are required' if payload['action'].nil? || payload['object_type'].nil? || payload['object_name'].nil?

        error = payload['error']
        context = payload['context']
        raise ValidationInvalidType, 'Context must be a hash' if !context.nil? && !context.kind_of?(Hash)

        begin
          timestamp = payload['timestamp'].nil? ? Time.new : timestamp_filter_value(payload['timestamp'])
        rescue ArgumentError
          status(400)
          body("Invalid timestamp parameter: '#{payload['timestamp']}' ")
          return
        end

        @event_manager.create_event(
          {
            timestamp:   timestamp,
            user:        current_user,
            action:      payload['action'],
            object_type: payload['object_type'],
            object_name: payload['object_name'],
            deployment:  payload['deployment'],
            instance:    payload['instance'],
            error:       error,
            context:     context
          })

        status(200)
      end

      private

      def timestamp_filter_value(value)
        return Time.at(value.to_i).utc if integer?(value)
        Time.parse(value)
      end

      def integer?(string)
        string =~ /\A[-+]?\d+\z/
      end

      not_found do
        status(404)
        "Event not found"
      end
    end
  end
end
