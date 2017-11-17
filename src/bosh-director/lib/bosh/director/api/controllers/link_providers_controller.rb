require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class LinkProvidersController < BaseController
      register DeploymentsSecurity

      def initialize(config)
        super(config)
        @deployment_manager = Api::DeploymentManager.new
      end

      get '/', authorization: :read do
        if params['deployment'].nil?
          raise DeploymentRequired, 'Deployment name is required'
        end

        deployment = @deployment_manager.find_by_name(params['deployment'])

        result = []

        link_providers = Bosh::Director::Models::LinkProvider.where(deployment: deployment)
        link_providers.each do |link_provider|
          result << generate_provider_hash(link_provider)
        end

        body(json_encode(result))
      end

      private

      def generate_provider_hash(model)
        {
          :id => model.id,
          :name => model.name,
          :shared => model.shared,
          :deployment => model.deployment.name,
          :instance_group => model.instance_group,
          :content => model.content,
          :link_provider_definition =>
            {
              :type => model.link_provider_definition_type,
              :name => model.link_provider_definition_name,
            },
          :owner_object => {
            :type => model.owner_object_type,
            :name => model.owner_object_name,
          }
        }
      end
    end
  end
end
