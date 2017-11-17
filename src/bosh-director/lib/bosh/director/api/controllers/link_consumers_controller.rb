require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class LinkConsumersController < BaseController
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

        link_consumers = Bosh::Director::Models::LinkConsumer.where(deployment: deployment)
        link_consumers.each do |link_consumer|
          result << generate_consumer_hash(link_consumer)
        end

        body(json_encode(result))
      end

      private

      def generate_consumer_hash(model)
        {
          :id => model.id,
          :deployment => model.deployment.name,
          :instance_group => model.instance_group,
          :owner_object => {
            :type => model.owner_object_type,
            :name => model.owner_object_name,
          }
        }
      end
    end
  end
end
