require 'net/http'
require 'json'

module Bosh::Director::ConfigServer
  class DeploymentHTTPClient
    def initialize(deployment_name, http_client)
      @http_client = http_client
      @deployment_model = Bosh::Director::Models::Deployment.find(name: deployment_name)
    end

    def get(name)
      response = @http_client.get(name)

      if response.kind_of? Net::HTTPOK
        response_body = JSON.parse(response.body)

        mappings = Bosh::Director::Models::PlaceholderMapping.where(
          placeholder_name: response_body['name'],
          placeholder_id: response_body['id'],
          deployment_id: @deployment_model.id)

        if mappings.empty?
          Bosh::Director::Models::PlaceholderMapping.create(
            placeholder_name: response_body['name'],
            placeholder_id: response_body['id'],
            deployment: @deployment_model
          )
        end
      end

      response
    end

    def post(name, body)
      @http_client.post(name, body)
    end
  end
end

