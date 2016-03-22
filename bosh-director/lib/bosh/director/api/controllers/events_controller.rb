require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class EventsController < BaseController
      EVENT_LIMIT = 200

      get '/' do
        content_type(:json)

        events = Models::Event.order_by(:id.desc)

        if params['before_id']
          fetch_until = params['before_id'].to_i
          start_from = fetch_until > EVENT_LIMIT ? (fetch_until - (EVENT_LIMIT-1)) : 1
          events = events.where(:id => start_from..fetch_until)
        end

        events = events.map do |event|
          @event_manager.event_to_hash(event)
        end
        json_encode(events)
      end
    end
  end
end
