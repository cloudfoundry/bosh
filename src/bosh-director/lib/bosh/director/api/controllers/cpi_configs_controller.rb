require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class CpiConfigsController < BaseController
      post '/', :consumes => :yaml do
        manifest_text = request.body.read
        begin
          validate_manifest_yml(manifest_text, nil)

          latest_cpi_config = Bosh::Director::Api::CpiConfigManager.new.list(1)

          if latest_cpi_config.empty? || latest_cpi_config.first[:content] != manifest_text
            Bosh::Director::Api::CpiConfigManager.new.update(manifest_text)
            create_event
          end

        rescue => e
          create_event e
          raise e
        end
        status(201)
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

        cpi_configs = Bosh::Director::Api::CpiConfigManager.new.list(limit)
        json_encode(
            cpi_configs.map do |cpi_config|
              {
                  "properties" => cpi_config.content,
                  "created_at" => cpi_config.created_at,
              }
            end
        )
      end

      post '/diff', :consumes => :yaml do
        new_cpi_configs_hash = validate_manifest_yml(request.body.read, nil) || {}
        old_cpi_configs = Bosh::Director::Api::CpiConfigManager.new.latest

        old_cpi_configs_hash = old_cpi_configs&.raw_manifest || {}

        result = {}
        redact =  params['redact'] != 'false'
        begin
          diff = Changeset.new(old_cpi_configs_hash, new_cpi_configs_hash).diff(redact).order
          result['diff'] = diff.map { |l| [l.to_s, l.status] }
        rescue => error
          result['diff'] = []
          result['error'] = "Unable to diff cpi_config: #{error.inspect}\n#{error.backtrace.join("\n")}"
        end
        json_encode(result)
      end

      private
      def create_event(error = nil)
        @event_manager.create_event({
                                        user:        current_user,
                                        action:      "update",
                                        object_type: "cpi-config",
                                        error:       error
                                    })
      end
    end
  end
end
