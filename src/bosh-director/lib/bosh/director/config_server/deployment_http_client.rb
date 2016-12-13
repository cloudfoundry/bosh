require 'net/http'
require 'json'

module Bosh::Director::ConfigServer
  class DeploymentHTTPClient

    @@lock = Mutex.new

    def initialize(deployment_name, http_client)
      @http_client = http_client
      @deployment_model = Bosh::Director::Models::Deployment.find(name: deployment_name)
    end

    def get(name)
      response = @http_client.get(name)

      if response.kind_of? Net::HTTPOK
        response_body = JSON.parse(response.body)
        placeholder = response_body['data'][0]
        values = {placeholder_id: placeholder['id'], placeholder_name: placeholder['name'], deployment_id: @deployment_model.id}

        @@lock.synchronize {
          mapping = Bosh::Director::Models::PlaceholderMapping.find(values)
          Bosh::Director::Models::PlaceholderMapping.insert(values) if mapping.nil?
        }
      end

      response
    end

    def post(body)
      @http_client.post(body)
    end
  end
end

