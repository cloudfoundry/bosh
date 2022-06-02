require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class CloudConfigsController < BaseController
      post '/', :consumes => :yaml do
        config_name = name_from_params(params)
        manifest_text = request.body.read
        begin
          validate_manifest_yml(manifest_text)

          latest_cloud_config = Bosh::Director::Api::CloudConfigManager.new.list(1, config_name)

          if latest_cloud_config.empty? || latest_cloud_config.first[:content] != manifest_text
            Bosh::Director::Api::CloudConfigManager.new.update(manifest_text, config_name)
            create_event(config_name)
          end

        rescue => e
          create_event(config_name, e)
          raise e
        end
        status(201)
      end

      post '/diff', :consumes => :yaml do
        old_config_hash = cloud_config_or_empty(cloud_config_by_name(name_from_params(params)))
        new_config_hash = validate_manifest_yml(request.body.read) || {}

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

        config_name = name_from_params(params)

        cloud_configs = Bosh::Director::Api::CloudConfigManager.new.list(limit, config_name)

        json_encode(
          cloud_configs.map do |cloud_config|
            {
              "properties" => cloud_config.content,
              "created_at" => cloud_config.created_at,
            }
          end
        )
      end

      private

      def name_from_params(params)
        name = params['name']
        name.nil? || name.empty? ? 'default' : name
      end

      def cloud_config_by_name(config_name)
        Bosh::Director::Models::Config.latest_set('cloud').find do |cloud_config|
          cloud_config.name == config_name
        end
      end

      def cloud_config_or_empty(cloud_config_model)
        return {} if cloud_config_model.nil? || cloud_config_model.raw_manifest.nil?
        cloud_config_model.raw_manifest
      end

      def create_event(config_name, error = nil)
        @event_manager.create_event({
            user:        current_user,
            action:      'update',
            object_type: 'cloud-config',
            object_name: config_name,
            error:       error
        })
      end
    end
  end
end
