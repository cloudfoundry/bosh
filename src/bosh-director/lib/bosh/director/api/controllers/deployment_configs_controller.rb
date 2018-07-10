require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class DeploymentConfigsController < BaseController
      get '/', scope: :list_deployments do
        names = params.fetch('deployment', [])

        results = []
        Models::DeploymentsConfig.by_deployment_name(names).each do |dc|
          next unless @permission_authorizer.is_granted?(dc.deployment, :read, token_scopes)
          results << model_to_hash(dc.deployment, dc.config)
        end

        json_encode(results)
      end

      private

      def model_to_hash(deployment, config)
        {
          id: deployment.id,
          deployment: deployment.name,
          config: {
            id: config.id,
            type: config.type,
            name: config.name,
          },
        }
      end
    end
  end
end
