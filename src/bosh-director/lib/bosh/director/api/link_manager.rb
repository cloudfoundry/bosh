module Bosh::Director
  module Api
    class LinkManager
      include ApiHelper

      def initialize
        @external_type = 'external'
        @links_manager = nil
      end

      # TODO: Links: if we want to track the user link_create task, what to do with the username
      def create_link(username, json_payload)
        network_metadata = {}
        validate_link_payload(json_payload)
        consumer_data = json_payload['link_consumer']

        provider_intent = find_provider_intent(json_payload['link_provider_id'])
        raise "Invalid link_provider_id: #{json_payload['link_provider_id']}" if provider_intent.nil?

        validate_consumer_network(provider_intent, json_payload['network'], consumer_data['owner_object_name']) unless json_payload['network'].nil?

        @links_manager = Bosh::Director::Links::LinksManager.new(Bosh::Director::Config.logger, Bosh::Director::Config.event_log, provider_intent.serial_id)
        provider = provider_intent.link_provider # find_provider_by_id(provider_intent.link_provider_id)

        consumer = @links_manager.find_or_create_consumer(
          deployment_model: provider.deployment,
          instance_group_name: '',
          name: consumer_data['owner_object_name'],
          type: @external_type,
        )

        network_metadata['network'] = json_payload['network'] if json_payload.has_key?('network')
        consumer_intent = @links_manager.find_or_create_consumer_intent(
          link_consumer: consumer,
          link_original_name: provider.name,
          link_type: provider_intent.type,
          new_intent_metadata: network_metadata,
        )

        filter_content_and_create_link(consumer_intent)
      end

      def delete_link(username, link_id)
        link = find_link(link_id)
        raise Bosh::Director::LinkLookupError, "Invalid link id: #{link_id}" if link.nil?

        validate_link_external_type(link)

        delete_link_and_cleanup(link)
      end

      def link_address(link_id)
        link = find_link(link_id)

        raise Bosh::Director::LinkLookupError, "Could not find a link with id #{link_id}" if link.nil?
        raise Bosh::Director::LinkNotExternalError, 'Link is must be external to retrieve address' if link.link_consumer_intent.link_consumer.type != 'external'

        dns_encoder = LocalDnsEncoderManager.create_dns_encoder(false)
        link_content = JSON.parse(link.link_content)
        query_criteria = {
          deployment_name: link_content['deployment_name'],
          instance_group: link_content['instance_group'],
          default_network: link_content['default_network'],
          root_domain: link_content['domain'],
        }
        dns_encoder.encode_query(query_criteria)
      end

      private

      def delete_link_and_cleanup(link)
        consumer_intent = link.link_consumer_intent
        link.destroy
        if consumer_intent.links.nil? || consumer_intent.links.empty?
          consumer = consumer_intent.link_consumer
          consumer_intent.destroy

          consumer.destroy if consumer.intents.nil? || consumer.intents.empty?
        end
      end

      # TODO: Links: all provider and consumer related functions should be moved to respective managers/controller?

      def validate_link_payload(json_payload)
        if json_payload['link_provider_id'].nil? || json_payload['link_provider_id'] == ''
          raise 'Invalid request: `link_provider_id` must be provided'
        elsif !json_payload['link_provider_id'].is_a?(String)
          raise 'Invalid request: `link_provider_id` must be a String'
        elsif json_payload['link_consumer'].nil?
          raise 'Invalid request: `link_consumer` section must be defined'
        elsif json_payload['link_consumer']['owner_object_type'].nil? || json_payload['link_consumer']['owner_object_type'] != 'external'
          raise "Invalid request: `link_consumer.owner_object_type` should be 'external'"
        elsif json_payload['link_consumer']['owner_object_name'].nil? || json_payload['link_consumer']['owner_object_name'] == ''
          raise 'Invalid request: `link_consumer.owner_object_name` must not be empty'
        end
      end

      def validate_consumer_network(provider_intent, consumer_network, consumer_name)
        # TODO: Links: discuss about possibility of value of content being empty; will cause nil class error
        content = provider_intent.content
        provider_intent_networks = JSON.parse(content)['networks']

        if consumer_network && !provider_intent_networks.include?(consumer_network)
          raise Bosh::Director::LinkNetworkLookupError, "Can't resolve network: `#{consumer_network}` in provider id: #{provider_intent.id} for `#{consumer_name}`"
        end
      end

      def validate_link_external_type(link)
        consumer = link.link_consumer_intent.link_consumer
        raise Bosh::Director::LinkNotExternalError, 'Error deleting link: not a external link' if consumer.type != @external_type
      end

      def filter_content_and_create_link(consumer_intent)
        # global_use_dns should be the director default for external link
        global_use_dns = Bosh::Director::Config.local_dns_use_dns_addresses?
        @links_manager.resolve_consumer_intent(consumer_intent, global_use_dns, false)
      end

      def find_provider_intent(provider_intent_id)
        Bosh::Director::Models::Links::LinkProviderIntent.find(id: provider_intent_id)
      end

      def find_link(link_id)
        Bosh::Director::Models::Links::Link.find(id: link_id)
      end
    end
  end
end
