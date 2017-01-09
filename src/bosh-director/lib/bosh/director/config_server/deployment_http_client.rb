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
        variable = response_body['data'][0]
        insert_values = {
          variable_id: variable['id'],
          variable_name: variable['name'],
          set_id: @deployment_model.variables_set_id
        }

        check_values = {
          variable_name: variable['name'],
          set_id: @deployment_model.variables_set_id
        }

        @@lock.synchronize {
          mapping = Bosh::Director::Models::VariableMapping.find(check_values)
          Bosh::Director::Models::VariableMapping.insert(insert_values) if mapping.nil?
        }
      end

      response
    end

    def post(body)
      @http_client.post(body)
    end
  end
end

