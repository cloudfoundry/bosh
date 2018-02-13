require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class ConfigsController < BaseController

      get '/', scope: :list_configs do
        check(params, 'latest')

        unless ['true', 'false'].include?(params['latest'])
          raise ValidationInvalidValue, "'latest' must be 'true' or 'false'"
        end

        configs = Bosh::Director::Api::ConfigManager.new.find(
          type: params['type'],
          name: params['name'],
          latest: params['latest']
        ).select { |config| @permission_authorizer.is_granted?(config, :read, token_scopes) }

        result = configs.map {|config| sql_to_hash(config)}

        return json_encode(result)
      end

      post '/', scope: :update_configs, :consumes => :json do
        begin
          config_hash = parse_request_body(request.body.read)
          validate_type_and_name(config_hash)
          validate_config_content(config_hash['content'])

          latest_configs = Bosh::Director::Api::ConfigManager.new.find(
              type: config_hash['type'],
              name: config_hash['name'],
              latest: true
          )

          config = latest_configs.first

          @permission_authorizer.granted_or_raise(config, :admin, token_scopes) unless config.nil?

          if config.nil? || config[:content] != config_hash['content']
            teams = Models::Team.transform_admin_team_scope_to_teams(token_scopes)
            team_id = teams.empty? ? nil: teams.first.id
            config = Bosh::Director::Api::ConfigManager.new.create(config_hash['type'], config_hash['name'], config_hash['content'], team_id)
            create_event(config_hash['type'], config_hash['name'])
          end
        rescue => e
          type = config_hash ? config_hash['type'] : nil
          name = config_hash ? config_hash['name'] : nil
          create_event(type, name, e)
          raise e
        end
        status(201)
        json_encode(sql_to_hash(config))
      end

      post '/diff', scope: :list_configs, :consumes => :json do
        config_request = parse_request_body(request.body.read)
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

      delete '/', scope: :update_configs do
        check(params, 'type')
        check(params, 'name')

        config_manager = Bosh::Director::Api::ConfigManager.new

        latest_configs = config_manager.find(
          type: params['type'],
          name: params['name'],
          latest: true,
        )

        config = latest_configs.first

        if config.nil?
          status(404)
          return
        end

        @permission_authorizer.granted_or_raise(config, :admin, token_scopes)

        count = config_manager.delete(params['type'], params['name'])
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
        hash =
          {
            content: config.content,
            id: config.id.to_s, # id should be opaque to clients (may not be an int)
            type: config.type,
            name: config.name,
            team: nil,
            created_at: config.created_at.to_s,
          }
        hash['team'] = config.team.name unless config.team.nil?
        hash
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

      def parse_request_body(body)
        config_request = begin
          JSON.parse(body)
        rescue => e
          raise InvalidJsonError, "Invalid JSON request body: #{e.message}"
        end
        raise BadConfigRequest, 'JSON object expected' if !config_request.is_a?(Hash) || config_request.nil?
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
