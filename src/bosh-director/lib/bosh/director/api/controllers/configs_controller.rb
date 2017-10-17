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
          config_hash = load_yml(request.body.read)
          validate_type_and_name(config_hash)
          validate_config_content(config_hash['content'])
          config = Bosh::Director::Api::ConfigManager.new.create(config_hash['type'], config_hash['name'], config_hash['content'])
          create_event(config_hash['type'], config_hash['name'])
        rescue => e
          type = config_hash ? config_hash['type'] : nil
          name = config_hash ? config_hash['name'] : nil
          create_event(type, name, e)
          raise e
        end

        status(201)
        return json_encode(sql_to_hash(config))
      end

      post '/diff', :consumes => :yaml do
        config_request = load_yml(request.body.read)
        validate_type_and_name(config_request)

        begin
          new_config_hash = validate_config_content(config_request['content'])
        rescue => e
          status(400)
          return json_encode({
            'diff' => [],
            'error' => e.message
          })
        end

        old_config = Bosh::Director::Api::ConfigManager.new.find(
            type: config_request['type'],
            name: config_request['name'],
            latest: true
        ).first

        old_config_hash = if old_config.nil? || old_config.raw_manifest.nil?
          {}
        else
          old_config.raw_manifest
        end

        begin
          diff = Changeset.new(old_config_hash, new_config_hash).diff(true).order
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
          raise BadConfigRequest, "'#{name}' is required"
        end
      end

      def check_name_and_type(manifest, name, type)
        check(manifest, name)
        raise BadConfigRequest, "'#{name}' must be a #{type.to_s.downcase}" unless manifest[name].is_a?(type)
      end

      def validate_type_and_name(config)
        check_name_and_type(config, 'type', String)
        check_name_and_type(config, 'name', String)
      end

      def load_yml(body)
        config_request = begin
          YAML.load(body)
        rescue => e
          raise InvalidYamlError, "Incorrect YAML structure of the uploaded body: #{e.message}"
        end
        raise BadConfigRequest, 'YAML hash expected' if !config_request.is_a?(Hash) || config_request.nil?
        config_request
      end

      def validate_config_content(content)
       content = begin
          YAML.load(content)
        rescue => e
          raise BadConfig, "Config must be valid YAML: #{e.message}"
        end

       raise BadConfig, 'YAML hash expected' unless content.is_a?(Hash)

       content
      end
    end
  end
end
