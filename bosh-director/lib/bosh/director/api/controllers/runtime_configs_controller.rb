require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class RuntimeConfigsController < BaseController
      post '/', :consumes => :yaml do
        manifest_text = request.body.read
        begin
          validate_manifest_yml(manifest_text)
          Bosh::Director::Api::RuntimeConfigManager.new.update(manifest_text)
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

        runtime_configs = Bosh::Director::Api::RuntimeConfigManager.new.list(limit)
        json_encode(
            runtime_configs.map do |runtime_config|
            {
              "properties" => runtime_config.properties,
              "created_at" => runtime_config.created_at,
            }
        end
        )
      end

      private
      def create_event(error = nil)
        @event_manager.create_event({
            user:        current_user,
            action:      "update",
            object_type: "runtime-config",
            error:       error
        })
      end
    end
  end
end
