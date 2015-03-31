require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class CloudConfigsController < BaseController
      post '/', :consumes => :yaml do
        Bosh::Director::Api::CloudConfigManager.new.update(request.body)

        status(201)
      end
    end
  end
end
