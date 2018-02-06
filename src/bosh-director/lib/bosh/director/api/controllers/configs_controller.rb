require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class ConfigsController < BaseController
      get '/:id', scope: :read do
        id = params[:id].to_i
        return status(404) if params[:id] != id.to_s
        config = Bosh::Director::Api::ConfigManager.new.find_by_id(id)
        status(200)
        return json_encode(sql_to_hash(config))
      end

      get '/', scope: :list_configs do
        check(params, 'latest')

        raise ValidationInvalidValue, "'latest' must be 'true' or 'false'" unless %w[true false].include?(params['latest'])

        configs = Bosh::Director::Api::ConfigManager.new.find(
          type: params['type'],
          name: params['name'],
          latest: params['latest'],
        ).select { |config| @permission_authorizer.is_granted?(config, :read, token_scopes) }

        result = configs.map { |config| sql_to_hash(config) }

        return json_encode(result)
      end

      post '/', scope: :update_configs, consumes: :json do
        begin
          config_hash = parse_request_body(request.body.read)
          validate_type_and_name(config_hash)
          validate_config_content(config_hash['content'])

          latest_configs = Bosh::Director::Api::ConfigManager.new.find(
            type: config_hash['type'],
            name: config_hash['name'],
            latest: true,
          )

          config = latest_configs.first

          @permission_authorizer.granted_or_raise(config, :admin, token_scopes) unless config.nil?

          if config.nil? || config[:content] != config_hash['content']
            teams = Models::Team.transform_admin_team_scope_to_teams(token_scopes)
            team_id = teams.empty? ? nil : teams.first.id
            config = Bosh::Director::Api::ConfigManager.new.create(
              config_hash['type'],
              config_hash['name'],
              config_hash['content'],
              team_id,
            )
            create_event(config_hash['type'], config_hash['name'])
          end
        rescue StandardError => e
          type = config_hash ? config_hash['type'] : nil
          name = config_hash ? config_hash['name'] : nil
          create_event(type, name, e)
          raise e
        end
        status(201)
        json_encode(sql_to_hash(config))
      end

      post '/diff', scope: :list_configs, consumes: :json do
        config_request = parse_request_body(request.body.read)

        schema1, schema2 = validate_diff_request(config_request)

        if schema1
          old_config_hash, new_config_hash = contents_by_id(config_request)
        elsif schema2
          begin
            old_config_hash, new_config_hash = contents_from_body_and_current(config_request)
          rescue StandardError => e
            status(400)
            return json_encode(
              'diff' => [],
              'error' => e.message,
            )
          end
        else
          raise BadConfigRequest,
                %(Only two request formats are allowed:\n) +
                %(1. {"from":{"id":"<id>"},"to":{"id":"<id>"}}\n) +
                %(2. {"type":"<type>","name":"<name>","content":"<content>"})
        end

        begin
          diff = Changeset.new(old_config_hash, new_config_hash).diff(true).order
          result = {
            'diff' => diff.map { |l| [l.to_s, l.status] },
          }
        rescue StandardError => error
          result = {
            'diff' => [],
            'error' => "Unable to diff config content: #{error.inspect}\n#{error.backtrace.join("\n")}",
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
        @event_manager.create_event(
          user:        current_user,
          action:      'create',
          object_type: "config/#{type}",
          object_name: name,
          error:       error,
        )
      end

      def sql_to_hash(config)
        hash =
          {
            content: config.content,
            id: config.id.to_s, # id should be opaque to clients (may not be an int)
            type: config.type,
            name: config.name,
            created_at: config.created_at.to_s,
          }
        hash['teams'] = config.teams.map(&:name)
        hash
      end

      def check(param, name)
        raise BadConfigRequest, "'#{name}' is required" if param[name].nil? || param[name].empty?
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
        rescue StandardError => e
          raise InvalidJsonError, "Invalid JSON request body: #{e.message}"
        end
        raise BadConfigRequest, 'JSON object expected' if !config_request.is_a?(Hash) || config_request.nil?
        config_request
      end

      def validate_config_content(content)
        content = begin
           YAML.safe_load(content, [Symbol], [], true)
         rescue StandardError => e
           raise BadConfig, "Config must be valid YAML: #{e.message}"
         end

        raise BadConfig, 'YAML hash expected' unless content.is_a?(Hash)

        content
      end

      def contents_by_id(config_request)
        from_config = Bosh::Director::Models::Config[config_request['from']['id']]
        raise ConfigNotFound, "Config with ID '#{config_request['from']['id']}' not found." unless from_config

        to_config = Bosh::Director::Models::Config[config_request['to']['id']]
        raise ConfigNotFound, "Config with ID '#{config_request['to']['id']}' not found." unless to_config

        [from_config.raw_manifest, to_config.raw_manifest]
      end

      def contents_from_body_and_current(config_request)
        validate_type_and_name(config_request)

        new_config_hash = validate_config_content(config_request['content'])

        old_config = Bosh::Director::Api::ConfigManager.new.find(
          type: config_request['type'],
          name: config_request['name'],
          latest: true,
        ).first

        old_config_hash = if old_config.nil? || old_config.raw_manifest.nil?
                            {}
                          else
                            old_config.raw_manifest
                          end

        [old_config_hash, new_config_hash]
      end

      def validate_diff_request(config_request)
        allowed_format_1 = {
          'from' => { 'id' => /\d+/ },
          'to' => { 'id' => /\d+/ },
        }

        allowed_format_2 = {
          'type' => /.+/,
          'name' => /.+/,
          'content' => String,
        }

        schema1 = true
        schema2 = true
        begin
          Membrane::SchemaParser.parse { allowed_format_1 }.validate(config_request)
        rescue StandardError
          schema1 = false
        end

        begin
          Membrane::SchemaParser.parse { allowed_format_2 }.validate(config_request)
        rescue StandardError
          schema2 = false
        end

        [schema1, schema2]
      end
    end
  end
end
