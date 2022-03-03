require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api
    module Controllers
      class ConfigsController < BaseController
        get '/:id', scope: :read do
          config = ConfigManager.find_by_id(params['id'])
          status(200)
          json_encode(config.to_hash)
        end

        get '/', scope: :list_configs do
          limit = limit(params['limit'], params['latest'])

          configs = ConfigManager
                    .find(type: params['type'], name: params['name'], limit: limit)
                    .select { |config| @permission_authorizer.is_granted?(config, :read, token_scopes) }

          json_encode(configs.map(&:to_hash))
        end

        def parse_config
          config_hash = parse_request_body(request.body.read)
          validate_type_and_name(config_hash)
          content_hash = parse_config_content(config_hash['content'])
          config_hash['content'] = ensure_release_version_is_string(content_hash) if config_hash['type'] == 'runtime'

          config_hash
        rescue StandardError => e
          type = config_hash && config_hash['type']
          name = config_hash && config_hash['name']
          create_event(type, name, e)
          raise e
        end

        post '/', scope: :update_configs, consumes: :json do
          begin
            config_hash = parse_config

            config = ConfigManager.current(config_hash['type'], config_hash['name'])
            config_id = ConfigManager.id_as_string(config)

            expected_latest_id = config_hash['expected_latest_id']&.to_s
            raise BadExpectedConfigID if expected_latest_id && config_id != expected_latest_id

            @permission_authorizer.granted_or_raise(config, :admin, token_scopes) unless config.nil?

            if config.nil? || config[:content] != config_hash['content']
              config = create_config(config_hash)
              create_event(config_hash['type'], config_hash['name'])
            end
            status(201)
            json_encode(config.to_hash)
          rescue BadExpectedConfigID
            status(412)
            return json_encode(
              'latest_id' => config_id,
              'expected_latest_id' => expected_latest_id,
              'description' => "Latest Id: '#{config_id}' does not match expected latest id",
            )
          end
        end

        post '/diff', scope: :list_configs, consumes: :json do
          config_hash = parse_request_body(request.body.read)
          schema_name = validate_diff_request(config_hash)
          diff = {}
          begin
            old_config_hash, new_config_hash = if schema_name == 'from_content_to_current'
                                                 config = ConfigManager.current(config_hash['type'], config_hash['name'])
                                                 diff['from'] = { 'id' => ConfigManager.id_as_string(config) }
                                                 content_and_current_to_hash(config_hash, config)
                                               else
                                                 load_diff_request(config_hash, schema_name)
                                               end

            diff['diff'] = generate_diff(new_config_hash, old_config_hash)
            json_encode(diff)
          rescue BadConfig => error
            status(400)
            json_encode(
              'diff' => [],
              'error' => "Unable to diff config content: #{error.inspect}",
            )
          end
        end

        delete '/:id', scope: :update_configs do
          config = ConfigManager.find_by_id(params['id'])
          @permission_authorizer.granted_or_raise(config, :admin, token_scopes)

          count = ConfigManager.delete_by_id(params['id'])
          status(count.positive? ? 204 : 404)
        end

        delete '/', scope: :update_configs do
          check(params, 'type')
          check(params, 'name')

          latest_configs = ConfigManager.find(type: params['type'], name: params['name'], limit: 1)

          config = latest_configs.first

          if config.nil?
            status(404)
            return
          end

          @permission_authorizer.granted_or_raise(config, :admin, token_scopes)

          count = ConfigManager.delete(params['type'], params['name'])
          status(count.positive? ? 204 : 404)
        end

        private

        def create_event(type, name, error = nil)
          @event_manager.create_event(
            user: current_user,
            action: 'create',
            object_type: "config/#{type}",
            object_name: name,
            error: error,
          )
        end

        def check(param, name)
          raise BadConfigRequest, "'#{name}' is required" if param[name].nil? || param[name].empty?
        end

        def integer?(param)
          param == param.to_i.to_s
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

        def parse_config_content(content)
          begin
            content = YAML.safe_load(content, permitted_classes: [Symbol], aliases: true)
          rescue StandardError => e
            raise BadConfig, "Config must be valid YAML: #{e.message}"
          end

          raise BadConfig, 'YAML hash expected' unless content.is_a?(Hash)

          content
        end

        def content_and_current_to_hash(config_request, old_config)
          begin
            validate_type_and_name(config_request)
            new_config_hash = parse_config_content(config_request['content'])
            old_config_hash = Hash(old_config&.raw_manifest)
          rescue StandardError => e
            raise BadConfig, e.message
          end

          @permission_authorizer.granted_or_raise(old_config, :admin, token_scopes) unless old_config.nil?

          [old_config_hash, new_config_hash]
        end

        def validate_diff_request(config_request)
          id_schema = { 'id' => /\d+/ }
          content_schema = { 'content' => String }
          schemas = {
            'from_id_to_id' => { 'from' => id_schema, 'to' => id_schema },
            'from_id_to_content' => { 'from' => id_schema, 'to' => content_schema },
            'from_content_to_id' => { 'from' => content_schema, 'to' => id_schema },
            'from_content_to_content' => { 'from' => content_schema, 'to' => content_schema },
            'from_content_to_current' => { 'type' => /.+/, 'name' => /.+/, 'content' => String },
          }

          schemas.each do |schema_name, schema|
            begin
              Membrane::SchemaParser.parse { schema }.validate(config_request)
              return schema_name
            rescue Membrane::SchemaValidationError
              next
            end
          end

          raise BadConfigRequest, %(The following request formats are allowed:\n) +
                                  %(1. {"from":<config>,"to":<config>} ) +
                                  %(where <config> is either {"id":"<id>"} or {"content":"<content>"}\n) +
                                  %(2. {"type":"<type>","name":"<name>","content":"<content>"})
        end

        def load_config_by_id(id)
          config = ConfigManager.find_by_id(id)
          @permission_authorizer.granted_or_raise(config, :admin, token_scopes)
          config.raw_manifest
        end

        def load_diff_request(config_request, schema_name)
          old_config_hash = if schema_name.start_with?('from_id')
                              load_config_by_id(config_request['from']['id'])
                            elsif schema_name.start_with?('from_content')
                              parse_config_content(config_request['from']['content'])
                            end

          new_config_hash = if schema_name.end_with?('to_id')
                              load_config_by_id(config_request['to']['id'])
                            elsif schema_name.end_with?('to_content')
                              parse_config_content(config_request['to']['content'])
                            end

          [old_config_hash, new_config_hash]
        end

        def generate_diff(new_config_hash, old_config_hash)
          Changeset.new(old_config_hash, new_config_hash).diff(true).order.map { |l| [l.to_s, l.status] }
        rescue StandardError => error
          raise BadConfig, "Unable to diff config content: #{error.inspect}"
        end

        def create_config(config_hash)
          teams = Models::Team.transform_admin_team_scope_to_teams(token_scopes)
          ConfigManager.create(config_hash['type'], config_hash['name'], config_hash['content'], teams.first&.id)
        end

        def validate_limit(param_limit, param_latest)
          if param_limit
            raise BadConfigRequest, "'limit' must be a number" unless integer?(param_limit)

            raise BadConfigRequest, "'limit' must be larger than zero" if param_limit.to_i < 1
          end

          return unless param_latest

          raise BadConfigRequest, "'latest' must be 'true' or 'false'" unless %w[true false].include?(param_latest)
        end

        def limit(param_limit, param_latest)
          validate_limit(param_limit, param_latest)

          return param_limit.to_i if param_limit
          return 1 unless param_latest == 'false'

          ConfigManager.find_max_id
        end
      end
    end
  end
end
