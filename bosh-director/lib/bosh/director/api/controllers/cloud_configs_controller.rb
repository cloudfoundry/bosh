require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class CloudConfigsController < BaseController
      post '/', :consumes => :yaml do
        properties = request.body.string
        Bosh::Director::Api::CloudConfigManager.new.update(properties)

        status(201)
      end

      get '/' do
        if params['limit'].nil? || params['limit'].empty?
          status(400)
          body("limit is required")
          return
        end

        begin
          limit = Integer(params['limit'])
        rescue ArgumentError
          status(400)
          body("limit is invalid: '#{params['limit']}' is not an integer")
          return
        end

        cloud_configs = Bosh::Director::Api::CloudConfigManager.new.list(limit)
        json_encode(
          cloud_configs.map do |cloud_config|
            {
              "properties" => cloud_config.properties,
              "created_at" => cloud_config.created_at,
            }
        end
        )
      end
    end
  end
end
