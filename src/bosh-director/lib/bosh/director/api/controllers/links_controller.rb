require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class LinksController < BaseController
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

        Models::LinkConsumer.where(deployment: deployment).each do |consumer|
          links = Models::Link.where(link_consumer: consumer)
          links.each do |link|
            result << generate_link_hash(link)
          end
        end

        body(json_encode(result))
      end

      private

      def generate_link_hash(model)
        {
          :id => model.id,
          :name => model.name,
          :link_consumer_id => model.link_consumer_id,
          :link_provider_id => model.link_provider_id,
          :created_at => model.created_at,
        }
      end
    end
  end
end
