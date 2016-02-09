require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class CloudConfigsController < BaseController
      post '/', :consumes => :yaml do
        manifest_file_path = prepare_yml_file(request.body, 'cloud-config')
        manifest_text = File.read(manifest_file_path)

        Bosh::Director::Api::CloudConfigManager.new.update(manifest_text)
        status(201)
      end

      get '/', scope: :read do
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
    end
  end
end
