require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class VariablesController < BaseController
      register Bosh::Director::Api::Extensions::DeploymentsSecurity

      def initialize(config)
        super(config)
      end

      # GET /variables?name=/foo/bar/baz
      get '/', authorization: :create_deployment do
        return status(422) unless params['name']

        response = {
          'deployments' => [],
        }

        all_deployments = Bosh::Director::Models::Deployment.order_by(Sequel.asc(:name)).all

        all_deployments.map do |deployment|
          next unless @permission_authorizer.is_granted?(deployment, :read, token_scopes)

          variable = deployment.last_successful_variable_set.find_variable_by_name(params['name'])
          next unless variable

          deployment_using_variable = {
            'name' => deployment.name,
            'version' => variable.variable_id,
          }
          response['deployments'] << deployment_using_variable
        end

        json_encode(response)
      end
    end
  end
end
