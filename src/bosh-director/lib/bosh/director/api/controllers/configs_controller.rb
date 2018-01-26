require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class ConfigsController < BaseController

      get '/:id', scope: :read do
        config = Bosh::Director::Api::ConfigManager.new.find_by_id(params[:id])
        status(200)
        return json_encode(sql_to_hash(config))
      end

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

      post '/', :consumes => :json do
        begin
          config_hash = parse_request_body(request.body.read)
          validate_type_and_name(config_hash)
          validate_config_content(config_hash['content'])

          latest_configs = Bosh::Director::Api::ConfigManager.new.find(
              type: config_hash['type'],
              name: config_hash['name'],
              latest: true
          )

          if latest_configs.empty? || latest_configs.first[:content] != config_hash['content']
            config = Bosh::Director::Api::ConfigManager.new.create(config_hash['type'], config_hash['name'], config_hash['content'])
            create_event(config_hash['type'], config_hash['name'])
          else
            config = latest_configs.first
          end

        rescue => e
          type = config_hash ? config_hash['type'] : nil
          name = config_hash ? config_hash['name'] : nil
          create_event(type, name, e)
          raise e
        end
        status(201)
        return json_encode(sql_to_hash(config))
      end

      post '/diff', :consumes => :json do
        config_request = parse_request_body(request.body.read)

        schema1, schema2 = validate_diff_request(config_request)

        if schema1
          old_config_hash, new_config_hash = contents_by_id(config_request)
        elsif schema2
          begin
            old_config_hash, new_config_hash = contents_from_body_and_current(config_request)
          rescue => e
            status(400)
            return json_encode({
              'diff' => [],
              'error' => e.message
            })
          end
        else
          raise BadConfigRequest,
              %|Only two request formats are allowed:\n| +
              %|1. {"from":{"id":"<id>"},"to":{"id":"<id>"}}\n| +
              %|2. {"type":"<type>","name":"<name>","content":"<content>"}|
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
            id: config.id.to_s, # id should be opaque to clients (may not be an int)
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

      def contents_by_id(config_request)
        from_config = Bosh::Director::Models::Config[config_request['from']['id']]
        unless from_config
          raise ConfigNotFound, "Config with ID '#{config_request['from']['id']}' not found."
        end

        to_config = Bosh::Director::Models::Config[config_request['to']['id']]
        unless to_config
          raise ConfigNotFound, "Config with ID '#{config_request['to']['id']}' not found."
        end

        [from_config.raw_manifest, to_config.raw_manifest]
      end

      def contents_from_body_and_current(config_request)
        validate_type_and_name(config_request)

        new_config_hash = validate_config_content(config_request['content'])


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

        [old_config_hash, new_config_hash]
      end

      def validate_diff_request(config_request)
        allowed_format_1 = {
            'from' => { 'id' => /\d+/ },
            'to' => { 'id' => /\d+/ }
        }

        allowed_format_2 = {
            'type' => /.+/,
            'name' => /.+/,
            'content' => String
        }

        schema1 = true
        schema2 = true
        begin
          Membrane::SchemaParser.parse { allowed_format_1 }.validate(config_request)
        rescue
          schema1 = false
        end

        begin
          Membrane::SchemaParser.parse { allowed_format_2 }.validate(config_request)
        rescue
          schema2 = false
        end

        [schema1, schema2]
      end
    end
  end
end
