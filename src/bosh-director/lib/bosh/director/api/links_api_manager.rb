module Bosh::Director
  module Api
    class LinksApiManager
      include ApiHelper

      def initialize
        @external_type = 'external'
        @links_manager = nil
      end

      def create_link(json_payload)
        network_metadata = {}
        validate_link_payload(json_payload)
        consumer_data = json_payload['link_consumer']

        provider_intent = find_and_validate_provider_intent(json_payload['link_provider_id'])

        validate_consumer_network(provider_intent, json_payload['network'], consumer_data['owner_object']['name']) unless json_payload['network'].nil?

        @links_manager = Bosh::Director::Links::LinksManager.new(provider_intent.serial_id)
        provider = provider_intent.link_provider # find_provider_by_id(provider_intent.link_provider_id)

        consumer = @links_manager.find_or_create_consumer(
          deployment_model: provider.deployment,
          instance_group_name: '',
          name: consumer_data['owner_object']['name'],
          type: @external_type,
        )

        network_metadata['network'] = json_payload['network'] if json_payload.has_key?('network')
        consumer_intent = @links_manager.find_or_create_consumer_intent(
          link_consumer: consumer,
          link_original_name: provider_intent.original_name,
          link_type: provider_intent.type,
          new_intent_metadata: network_metadata,
        )
        consumer_intent.name = provider_intent.name
        consumer_intent.save

        filter_content_and_create_link(consumer_intent, provider_intent)
      end

      def delete_link(link_id)
        link = find_link(link_id)
        raise Bosh::Director::LinkLookupError, "Invalid link id: #{link_id}" if link.nil?

        validate_link_external_type(link)

        delete_link_and_cleanup(link)
      end

      def link_address(link_id, query_options = {})
        link = find_link(link_id)
        raise Bosh::Director::LinkLookupError, "Could not find a link with id #{link_id}" if link.nil?

        link_content = JSON.parse(link.link_content)

        return link_content['address'] if link.link_provider_intent&.link_provider&.type == 'manual'

        use_short_dns_addresses = link_content.fetch('use_short_dns_addresses', false)
        use_link_dns_names = link_content.fetch('use_link_dns_names', false)
        dns_encoder = LocalDnsEncoderManager.create_dns_encoder(use_short_dns_addresses, use_link_dns_names)

        group_name, group_type = if use_link_dns_names
                                   [link.group_name, Models::LocalDnsEncodedGroup::Types::LINK]
                                 else
                                   [link_content['instance_group'], Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP]
                                 end

        query_criteria = {
          group_name: group_name,
          group_type: group_type,
          deployment_name: link_content['deployment_name'],
          default_network: link_content['default_network'],
          root_domain: link_content['domain'],
          azs: query_options[:azs],
          status: query_options[:status],
        }
        dns_encoder.encode_query(query_criteria)
      end

      private

      def find_and_validate_provider_intent(provider_intent_id)
        provider_intent = find_provider_intent(provider_intent_id)
        raise Bosh::Director::LinkProviderLookupError, "Invalid link_provider_id: #{provider_intent_id}" if provider_intent.nil?
        raise Bosh::Director::LinkProviderNotSharedError, "Provider not `shared`" unless provider_intent.shared
        provider_intent
      end

      def delete_link_and_cleanup(link)
        consumer_intent = link.link_consumer_intent
        link.destroy
        if consumer_intent.links.nil? || consumer_intent.links.empty?
          consumer = consumer_intent.link_consumer
          consumer_intent.destroy

          consumer.destroy if consumer.intents.nil? || consumer.intents.empty?
        end
      end

      def validate_link_payload(json_payload)
        if json_payload['link_provider_id'].nil? || json_payload['link_provider_id'] == ''
          raise 'Invalid request: `link_provider_id` must be provided'
        elsif !json_payload['link_provider_id'].is_a?(String)
          raise 'Invalid request: `link_provider_id` must be a String'
        elsif json_payload['link_consumer'].nil?
          raise 'Invalid request: `link_consumer` section must be defined'
        elsif json_payload['link_consumer']['owner_object'].nil?
          raise 'Invalid request: `link_consumer.owner_object` section must be defined'
        elsif json_payload['link_consumer']['owner_object']['type'].nil? || json_payload['link_consumer']['owner_object']['type'] != @external_type
          raise "Invalid request: `link_consumer.owner_object.type` should be 'external'"
        elsif json_payload['link_consumer']['owner_object']['name'].nil? || json_payload['link_consumer']['owner_object']['name'] == ''
          raise 'Invalid request: `link_consumer.owner_object.name` must not be empty'
        end
      end

      def validate_consumer_network(provider_intent, consumer_network, consumer_name)
        content = provider_intent.content || '{}'
        provider_intent_networks = JSON.parse(content)['networks']

        if consumer_network && (
          provider_intent_networks.nil? ||
          !provider_intent_networks.include?(consumer_network))
          raise Bosh::Director::LinkNetworkLookupError,
                "Can't resolve network: `#{consumer_network}` in provider id: #{provider_intent.id} for `#{consumer_name}`"
        end
      end

      def validate_link_external_type(link)
        consumer = link.link_consumer_intent.link_consumer
        raise Bosh::Director::LinkNotExternalError, 'Error deleting link: not a external link' if consumer.type != @external_type
      end

      def filter_content_and_create_link(consumer_intent, provider_intent)
        # global_use_dns should be the director default for external link
        global_use_dns = Bosh::Director::Config.local_dns_use_dns_addresses?
        @links_manager.resolve_consumer_intent_and_generate_link(consumer_intent, global_use_dns, false, provider_intent)
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
