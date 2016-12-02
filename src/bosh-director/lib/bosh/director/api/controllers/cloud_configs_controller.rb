require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class CloudConfigsController < BaseController
      post '/', :consumes => :yaml do
        manifest_text = request.body.read
        begin
          validate_manifest_yml(manifest_text, nil)
          Bosh::Director::Api::CloudConfigManager.new.update(manifest_text)
          create_event
        rescue => e
          create_event e
          raise e
        end

        status(201)
      end

      get '/', scope: :read do
        if params['limit'].nil? || params['limit'].empty?
          status(400)
          body('limit is required')
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

      private
      def create_event(error = nil)
        @event_manager.create_event({
            user:        current_user,
            action:      "update",
            object_type: "cloud-config",
            error:       error
        })
      end
    end
  end
end
