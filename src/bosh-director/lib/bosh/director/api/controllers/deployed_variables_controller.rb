require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class DeployedVariablesController < BaseController
      register Bosh::Director::Api::Extensions::DeploymentsSecurity
      set :protection, except: :path_traversal

      def initialize(config)
        super(config)
      end

      # GET /deployed_variables/:name
      get '/:name', authorization: :read do
        response = {
          'deployments' => [],
        }

        all_deployments = Bosh::Director::Models::Deployment.order_by(Sequel.asc(:name)).all

        all_deployments.map do |deployment|
          next unless @permission_authorizer.is_granted?(deployment, :read, token_scopes)

          variable = deployment.last_successful_variable_set.find_variable_by_name(params[:name])
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
