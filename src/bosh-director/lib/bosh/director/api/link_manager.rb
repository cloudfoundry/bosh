module Bosh::Director
  module Api
    class LinkManager
      include ApiHelper

      def initialize
        @external_type = "external"
        @links_manager = nil
      end

      #TODO Links: if we want to track the user link_create task, what to do with the username
      def create_link(username, json_payload)
        validate_link_payload(json_payload)
        consumer_data = json_payload["link_consumer"]

        provider_intent = find_provider_intent(json_payload["link_provider_id"])
        if provider_intent.nil?
          raise "Invalid link_provider_id: #{json_payload["link_provider_id"]}"
        end

        validate_consumer_network(provider_intent, json_payload["network"], consumer_data["owner_object_name"]) unless json_payload["network"].nil?

        @links_manager = Bosh::Director::Links::LinksManager.new(Bosh::Director::Config.logger, Bosh::Director::Config.event_log, provider_intent.serial_id)
        provider = provider_intent.link_provider #find_provider_by_id(provider_intent.link_provider_id)

        consumer = @links_manager.find_or_create_consumer(
          deployment_model: provider.deployment,
          instance_group_name: provider.instance_group,
          name: consumer_data["owner_object_name"],
          type:@external_type
        )
        consumer_intent = @links_manager.find_or_create_consumer_intent(
          link_consumer: consumer,
          link_original_name: provider.name,
          link_type: provider_intent.type
        )

        filter_content_and_create_link(consumer_intent)
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

      def filter_content_and_create_link(consumer_intent)
        # global_use_dns should be the director default for external link
        global_use_dns = Bosh::Director::Config.local_dns_use_dns_addresses?
        @links_manager.resolve_consumer_intent(consumer_intent, global_use_dns, false)
      end

      def find_provider_intent(provider_intent_id)
        Bosh::Director::Models::Links::LinkProviderIntent.find(id: provider_intent_id)
      end

      def validate_consumer_network(provider_intent, consumer_network, consumer_name)
        # TODO Links: discuss about possibility of value of content being empty; will cause nil class error
        content = provider_intent.content
        provider_intent_networks = JSON.parse(content)['networks']

        if consumer_network && !provider_intent_networks.include?(consumer_network)
          raise Bosh::Director::LinkNetworkLookupError, "Can't resolve network: `#{consumer_network}` in provider id: #{provider_intent.id} for `#{consumer_name}`"
        end
      end
    end
  end
end
