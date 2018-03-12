module Bosh::Director
  module Api
    class LinkManager
      include ApiHelper

      def initialize
        # @links_manager = Bosh::Director::Links::LinksManager
        # @provider_controller = Api::LinkProvidersController
        @external_type = "external"
      end

      #TODO Links: if we want to track the user initiated the link_create task, what to do with the username
      def create_link(username, json_payload)
        validate_link_payload(json_payload)
        provider_intent = find_provider_intent(json_payload["link_provider_id"])
        if provider_intent.nil?
          raise "Invalid link_provider_id: #{json_payload["link_provider_id"]}"
        end
        provider = find_provider_by_id(provider_intent.link_provider_id)

        consumer_data = json_payload["link_consumer"]
        consumer = create_consumer(consumer_data["owner_object_name"], provider)
        consumer_intent = create_consumer_intent(consumer, provider.name, provider.type)

        create_external_link(consumer_data["owner_object_name"], provider_intent, consumer_intent)
      end


      private

      # TODO Links: all provider and consumer related functions should be moved to respective managers/controller?

      def validate_link_payload(json_payload)
        # TODO Links: check if Integer validation is required or not?
        if  json_payload["link_provider_id"].nil? || !(json_payload["link_provider_id"].is_a?(Integer))
          raise "Invalid json: provide valid `link_provider_id`"
        elsif json_payload["link_consumer"].nil?
          raise "Invalid json: missing `link_consumer`"
        elsif json_payload["link_consumer"]["owner_object_name"].nil? || json_payload["link_consumer"]["owner_object_name"] == ""
          raise "Invalid json: provide valid `owner_object_name`"
        end
      end

      def find_provider_by_id(provider_id)
        Bosh::Director::Models::Links::LinkProvider.find(id: provider_id)
      end

      def find_provider_intent(provider_intent_id)
        Bosh::Director::Models::Links::LinkProviderIntent.find(id: provider_intent_id)
      end

      def create_consumer(owner_object_name, provider)
        # TODO Links: serial_id is not taken under consideration during create step
        Bosh::Director::Models::Links::LinkConsumer.find_or_create(
          deployment: provider.deployment,
          instance_group: provider.instance_group,
          name: owner_object_name,
          type: @external_type,
          )
      end

      def create_consumer_intent(consumer, provider_original_name, provider_type)
        Bosh::Director::Models::Links::LinkConsumerIntent.find_or_create(
          link_consumer: consumer,
          original_name: provider_original_name,
          type: provider_type,
          )
      end

      # TODO Links: find out the link name ?
      def create_external_link(link_name, provider_intent, consumer_intent)
        Bosh::Director::Models::Links::Link.find_or_create(
          name: link_name,
          link_provider_intent_id: provider_intent && provider_intent[:id],
          link_consumer_intent_id: consumer_intent && consumer_intent[:id],
          link_content: provider_intent[:content]
        )
      end

    end
  end
end
