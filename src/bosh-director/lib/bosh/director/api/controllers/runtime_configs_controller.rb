require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class RuntimeConfigsController < BaseController
      post '/', :consumes => :yaml do
        config_name = name_from_params(params)
        manifest_text = request.body.read
        begin
          validate_manifest_yml(manifest_text, nil)
          Bosh::Director::Api::RuntimeConfigManager.new.update(manifest_text, config_name)
          create_event(config_name)
        rescue => e
          create_event(config_name, e)
          raise e
        end

        status(201)
      end

      post '/diff', :consumes => :yaml do
        old_runtime_config = runtime_config_or_empty(runtime_config_by_name(name_from_params(params)))
        new_runtime_config = validate_manifest_yml(request.body.read, nil) || {}

        result = {}
        redact = params['redact'] != 'false'
        begin
          diff = Changeset.new(old_runtime_config, new_runtime_config).diff(redact).order
          result['diff'] = diff.map { |l| [l.to_s, l.status] }
        rescue => error
          result['diff'] = []
          result['error'] = "Unable to diff runtime-config: #{error.inspect}\n#{error.backtrace.join("\n")}"
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

        runtime_configs = Bosh::Director::Api::RuntimeConfigManager.new.list(limit, config_name)

        json_encode(
            runtime_configs.map do |runtime_config|
            {
              'properties' => runtime_config.content,
              'created_at' => runtime_config.created_at,
            }
        end
        )
      end

      private

      def name_from_params(params)
        name = params['name']
        name.nil? || name.empty? ? 'default' : name
      end

      def runtime_config_by_name(config_name)
        Bosh::Director::Models::Config.latest_set('runtime').find do |runtime_config|
          runtime_config.name == config_name
        end
      end

      def runtime_config_or_empty(runtime_config_model)
        return {} if runtime_config_model.nil? || runtime_config_model.raw_manifest.nil?
        runtime_config_model.raw_manifest
      end

      def create_event(config_name, error = nil)
        @event_manager.create_event({
            user:        current_user,
            action:      'update',
            object_type: 'runtime-config',
            object_name: config_name,
            error:       error
        })
      end
    end
  end
end
