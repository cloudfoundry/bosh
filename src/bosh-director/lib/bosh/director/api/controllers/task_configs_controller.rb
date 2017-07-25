require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class TaskConfigsController < BaseController
      def initialize(config)
        super(config)
        @task_config_manager = Bosh::Director::Api::TasksConfigManager.new()
      end

      post '/', :consumes => :yaml do
        begin
          manifest_text = request.body.read
          validate_manifest_yml(manifest_text, nil)
          @task_config_manager.update(manifest_text)
          create_event
        rescue => e
          create_event e
          raise e
        end
        status(200)
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

        task_configs = @task_config_manager.list(limit)
        json_encode(
            task_configs.map do |task_config|
              {
                  "properties" => task_config.properties,
                  "created_at" => task_config.created_at,
              }
            end
        )
      end

      private

      def create_event(error = nil)
        @event_manager.create_event({
                                        user:        current_user,
                                        action:      "update",
                                        object_type: "task-config",
                                        error:       error
                                    })
      end

    end
  end
end
