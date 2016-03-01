require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class EventsController < BaseController
      get '/' do
        content_type(:json)
        events = Models::Event.order_by(:id.desc).map do |event|
          @event_manager.event_to_hash(event)
        end
        json_encode(events)
      end
    end
  end
end
