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

      post '/diff', :consumes => :yaml do
        new_config_hash = validate_manifest_yml(request.body.read, nil)
        cloud_config = Bosh::Director::Api::CloudConfigManager.new.latest
        old_config_hash = cloud_config ? cloud_config.manifest : {}

        result = {}
        begin
          diff = Changeset.new(old_config_hash, new_config_hash).diff(false).order
          result['diff'] = diff.map { |l| [l.to_s, l.status] }
        rescue => error
          result['diff'] = []
          result['error'] = "Unable to diff cloud-config: #{error.inspect}\n#{error.backtrace.join("\n")}"
        end

        json_encode(result)
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
