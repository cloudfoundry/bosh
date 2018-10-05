require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class LinksController < BaseController
      register Bosh::Director::Api::Extensions::DeploymentsSecurity

      def initialize(config)
        super(config)
        @deployment_manager = Api::DeploymentManager.new
        @links_api_manager = Api::LinksApiManager.new
      end

      get '/', authorization: :read do
        if params['deployment'].nil?
          raise DeploymentRequired, 'Deployment name is required'
        end

        deployment = @deployment_manager.find_by_name(params['deployment'])

        result = []

        Models::Links::LinkConsumer.where(deployment: deployment).each do |consumer|
          Models::Links::LinkConsumerIntent.where(link_consumer: consumer).each do |consumer_intent|
            links = Models::Links::Link.where(link_consumer_intent: consumer_intent)
            links.each do |link|
              result << generate_link_hash(link)
            end
          end
        end

        body(json_encode(result))
      end

      post '/', authorization: :create_link, consumes: :json do
        payload = JSON.parse(request.body.read)
        begin
          link = @links_api_manager.create_link(payload)
          link_hash = generate_link_hash(link)

          body(json_encode(link_hash))
        rescue RuntimeError => e
          raise LinkCreateError, e
        end
      end

      delete '/:linkid', authorization: :delete_link do
        begin
          @links_api_manager.delete_link(params[:linkid])
        rescue RuntimeError => e
          raise LinkDeleteError, e
        end
        status(204)
        body(nil)
      end

      private

      def generate_link_hash(model)
        {
          :id => model.id.to_s,
          :name => model.name,
          :link_consumer_id => model[:link_consumer_intent_id].to_s,
          :link_provider_id => (model[:link_provider_intent_id].nil? ? nil : model[:link_provider_intent_id].to_s),
          :created_at => model.created_at,
        }
      end
    end
  end
end
