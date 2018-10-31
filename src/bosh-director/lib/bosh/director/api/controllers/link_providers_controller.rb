require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class LinkProvidersController < BaseController
      register Bosh::Director::Api::Extensions::DeploymentsSecurity

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

        link_providers = Bosh::Director::Models::Links::LinkProvider.where(deployment: deployment)
        link_providers.each do |link_provider|
          link_provider.intents.each do |link_provider_intent|
            result << generate_provider_hash(link_provider_intent)
          end
        end

        body(json_encode(result))
      end

      private

      def generate_provider_hash(model)
        provider = model.link_provider
        {
          :id => model.id.to_s,
          :name => model.name,
          :shared => model.shared,
          :deployment => provider.deployment.name,
          :link_provider_definition =>
            {
              :type => model.type,
              :name => model.original_name,
            },
          :owner_object => {
            :type => provider.type,
            :name => provider.name,
            :info => {
              :instance_group => provider.instance_group,
            }
          }
        }
      end
    end
  end
end
