require 'bosh/director/api/controllers/base_controller'
require 'time'

module Bosh::Director
  module Api::Controllers
    class EventsController < BaseController
      EVENT_LIMIT = 200

      get '/' do
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

        events = events.limit(EVENT_LIMIT).map do |event|
          @event_manager.event_to_hash(event)
        end
        json_encode(events)
      end

      private

      def timestamp_filter_value(value)
        return Time.at(value.to_i).utc if integer?(value)
        Time.parse(value)
      end

      def integer?(string)
        string =~ /\A[-+]?\d+\z/
      end
    end
  end
end
