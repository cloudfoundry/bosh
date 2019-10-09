require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class ResurrectionController < BaseController
      get '/' do
        json_encode(resurrection: !@resurrector_manager.pause_for_all?)
      end

      put '/', consumes: :json do
        payload = json_decode(request.body.read)

        @resurrector_manager.set_pause_for_all(payload['resurrection_paused'])
        status(200)
      end
    end
  end
end
