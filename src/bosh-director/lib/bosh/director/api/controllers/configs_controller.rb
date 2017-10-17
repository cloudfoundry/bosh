require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class ConfigsController < BaseController

      get '/', scope: :read do
        check(params, 'latest')

        unless ['true', 'false'].include?(params['latest'])
          raise ValidationInvalidValue, "'latest' must be 'true' or 'false'"
        end

        configs = Bosh::Director::Api::ConfigManager.new.find(
          type: params['type'],
          name: params['name'],
          latest: params['latest']
        )

        result = configs.map {|config| sql_to_hash(config)}

        return json_encode(result)
      end

      post '/', :consumes => :yaml do
        begin
          manifest = {}
          manifest = validate_yml(request.body.read, 'body')
          validate_create_format(manifest)
          config = Bosh::Director::Api::ConfigManager.new.create(manifest['type'], manifest['name'], manifest['content'])
          create_event(manifest['type'], manifest['name'])
        rescue => e
          if manifest.is_a?(Hash) && manifest.key?('type') && manifest.key?('name')
            create_event(manifest['type'], manifest['name'], e)
          else
            create_event('invalid type', 'invalid name', e)
          end

          raise e
        end

        status(201)
        return json_encode(sql_to_hash(config))
      end

      post '/diff', :consumes => :yaml do
        body = validate_yml(request.body.read, 'body')
        new_config_hash = validate_yml(body['content'], 'config content') || {}

        old_config = Bosh::Director::Api::ConfigManager.new.find(
            type: body['type'],
            name: body['name'],
            latest: true
        ).first

        old_config_hash = if old_config.nil? || old_config.raw_manifest.nil?
          {}
        else
          old_config.raw_manifest
        end

        begin
          diff = Changeset.new(old_config_hash, new_config_hash).diff(false).order
          result = {
            'diff' => diff.map { |l| [l.to_s, l.status] }
          }
        rescue => error
          result = {
            'diff' => [],
            'error' => "Unable to diff config content: #{error.inspect}\n#{error.backtrace.join("\n")}"
          }
          status(400)
        end

        json_encode(result)
      end

      delete '/' do
        check(params, 'type')
        check(params, 'name')

        count = Bosh::Director::Api::ConfigManager.new.delete(params['type'], params['name'])
        if count > 0
          status(204)
        else
          status(404)
        end
      end

      private

      def create_event(type, name, error = nil)
        @event_manager.create_event({
          user:        current_user,
          action:      'create',
          object_type: "config/#{type}",
          object_name: name,
          error:       error
        })
      end

      def sql_to_hash(config)
        {
            content: config.content,
            id: config.id,
            type: config.type,
            name: config.name
        }
      end

      def check(param, name)
        if param[name].nil? || param[name].empty?
          raise ValidationMissingField, "'#{name}' is required"
        end
      end

      def check_name_and_type(manifest, name)
        check(manifest, name)
        raise InvalidYamlError, "'#{name}' must be a string" unless manifest[name].is_a?(String)
      end

      def validate_create_format(manifest)
        raise InvalidYamlError, "YAML hash expected" unless manifest.is_a?(Hash)
        check_name_and_type(manifest, 'type')
        check_name_and_type(manifest, 'name')
        check_name_and_type(manifest, 'content')
      end

    end
  end
end
