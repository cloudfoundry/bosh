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
      get '/:name', authorization: :list_deployments do
        all_deployments = Models::Deployment.order_by(Sequel.asc(:name)).all
        deployments_response = all_deployments.map do |deployment|
          next unless @permission_authorizer.is_granted?(deployment, :read, token_scopes)

          variable = deployment.last_successful_variable_set&.find_variable_by_name(params[:name])
          next unless variable

          {
            'name' => deployment.name,
            'version' => variable.variable_id,
          }
        end.compact

        response = {
          'deployments' => deployments_response,
        }

        json_encode(response)
      end
    end
  end
end
