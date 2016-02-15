require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class EventsController < BaseController
      get '/' do
        content_type(:json)
        events = Models::Event.order_by(:id.asc).map do |event|
          {
              "id"           => event.id,
              "target_type"  => event.target_type,
              "target_name"  => event.target_name,
              "event_action" => event.event_action,
              "event_state"  => event.event_state,
              "event_result" => truncate(event.event_result),
              "task_id"      => event.task_id,
              "timestamp"    => event.timestamp.to_i,
          }
        end
        json_encode(events)
      end

      private
      def truncate(string, len = 128)
        stripped = string.strip[0..len]
        if stripped.length > len
          stripped.gsub(/\s+?(\S+)?$/, "") + "..."
        else
          stripped
        end
      end
    end
  end
end
