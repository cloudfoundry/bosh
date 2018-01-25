require 'SecureRandom'

module Bosh::Director::Links
  class LinksManager
    include Bosh::Director::IpUtil

    def initialize(logger)
      # @context_id = SecureRandom.uuid
      @logger = logger
    end

    def find_or_create_provider(
      deployment_model:,
      instance_group_name:,
      name:,
      type:
    )
      Bosh::Director::Models::Links::LinkProvider.find_or_create(
        deployment: deployment_model,
        instance_group: instance_group_name,
        name: name,
        type: type
      )
    end

    def find_provider(
      deployment_model:,
      instance_group_name:,
      name:,
      type:
    )
      Bosh::Director::Models::Links::LinkProvider.find(
        deployment: deployment_model,
        instance_group: instance_group_name,
        name: name,
        type: type
      )
    end

    def find_providers(
      deployment:
    )
      Bosh::Director::Models::Links::LinkProvider.where(
        deployment: deployment
      ).all
    end

    # Used by provider, not using alias because want to update existing provider intent when alias changes
    def find_or_create_provider_intent(
      link_provider:,
      link_original_name:,
      link_type:
    )
      Bosh::Director::Models::Links::LinkProviderIntent.find_or_create(
        link_provider: link_provider,
        original_name: link_original_name,
        type: link_type
      )
    end

    def find_provider_intent_by_original_name(
      link_provider:,
      link_original_name:,
      link_type:
    )
      Bosh::Director::Models::Links::LinkProviderIntent.find(
        link_provider: link_provider,
        original_name: link_original_name,
        type: link_type,
        consumable: true
      )
    end

    # Used by consumer
    def find_provider_intent_by_alias(
      link_provider:,
      link_alias:,
      link_type:
    )
      Bosh::Director::Models::Links::LinkProviderIntent.find(
        link_provider: link_provider,
        name: link_alias,
        type: link_type,
        consumable: true
      )
    end

    def find_or_create_consumer(
      deployment_model:,
      instance_group_name:,
      name:,
      type:
    )
      Bosh::Director::Models::Links::LinkConsumer.find_or_create(
        deployment: deployment_model,
        instance_group: instance_group_name,
        name: name,
        type: type
      )
    end

    def find_consumer(
      deployment_model:,
      instance_group_name:,
      name:,
      type:
    )
      Bosh::Director::Models::Links::LinkConsumer.find(
        deployment: deployment_model,
        instance_group: instance_group_name,
        name: name,
        type: type
      )
    end

    def find_or_create_consumer_intent(
      link_consumer:,
      link_original_name:,
      link_type:
    )
      Bosh::Director::Models::Links::LinkConsumerIntent.find_or_create(
        link_consumer: link_consumer,
        original_name: link_original_name,
        type: link_type
      )
    end

    def find_or_create_link(
      name:,
      provider_intent:,
      consumer_intent:,
      link_content:
    )
      found_link = Bosh::Director::Models::Links::Link.find(
        link_provider_intent_id: provider_intent && provider_intent[:id],
        link_consumer_intent_id: consumer_intent && consumer_intent[:id],
        link_content: link_content
      )

      unless found_link
        Bosh::Director::Models::Links::Link.create(
          name: name,
          link_provider_intent_id: provider_intent && provider_intent[:id],
          link_consumer_intent_id: consumer_intent && consumer_intent[:id],
          link_content: link_content
        )
      end
    end

    def find_link(
      name:,
      provider_intent:,
      consumer_intent:
    )
      Bosh::Director::Models::Links::Link.find(
        link_provider_intent_id: provider_intent && provider_intent[:id],
        link_consumer_intent_id: consumer_intent && consumer_intent[:id],
        name: name
      )
    end

    def resolve_deployment_links(deployment, dry_run = false)
      consumers = Bosh::Director::Models::Links::LinkConsumer.where(deployment: deployment.model).all

      consumers.each do |consumer|
        resolve_consumer(consumer, deployment.use_dns_addresses?, dry_run)
      end
    end

    def resolve_consumer(consumer, global_use_dns_entry, dry_run = false)
      consumer.intents&.each do |consumer_intent|
        resolve_consumer_intent(consumer_intent, global_use_dns_entry, dry_run)
      end
    end

    def resolve_consumer_intent(consumer_intent, global_use_dns_entry, dry_run = false)
      manual_provider_intents = get_manual_link_provider_for_consumer(consumer_intent)
      if !manual_provider_intents.nil? && (manual_provider_intents.size == 1)
        provider_intent = manual_provider_intents.first
        link_content = provider_intent.content || '{}'

        find_or_create_link(
          name: consumer_intent.original_name,
          provider_intent: provider_intent,
          consumer_intent: consumer_intent,
          link_content: link_content
        ) unless dry_run

        # TODO LINKS: Remove this when we clean up instance group. This was used by the instance_spec class.
        # instance_group.add_resolved_link(provider_intent.link_provider.name, consumer_intent.original_name, JSON.parse(provider_intent.content))
      else
        consumer = consumer_intent.link_consumer

        consumer_intent_metadata = {}
        consumer_intent_metadata = JSON.parse(consumer_intent.metadata) unless consumer_intent.metadata.nil?
        deployment_name = consumer_intent_metadata['from_deployment'] || consumer.deployment.name
        link_network = consumer_intent_metadata['network']
        is_explicit_link = !!consumer_intent_metadata['explicit_link']

        deployment = Bosh::Director::Models::Deployment.find(name: deployment_name)
        unless deployment
          raise Bosh::Director::DeploymentRequired, "Can't find deployment '#{deployment_name}'"
        end

        is_cross_deployment = consumer.deployment.name != deployment_name

        found_provider_intents = []
        found_providers = find_providers(deployment: deployment)

        found_providers.each do |provider|
          provider.intents.each do |provider_intent|
            next if provider_intent.type != consumer_intent.type

            if is_explicit_link
              next if provider_intent[:name] != consumer_intent.name
              next if is_cross_deployment && !provider_intent.shared

              # Shared providers would already have contents populated.
              # We are likely within the same deployment if it is empty and just validating.
              # Let the validation be a bit more loose.
              unless provider_intent.content.nil?
                provider_intent_networks = JSON.parse(provider_intent.content)['networks']
                next if link_network && !provider_intent_networks.include?(link_network)
              end
            end

            found_provider_intents << provider_intent
          end
        end

        if found_provider_intents.size != 1
          if is_explicit_link
            if found_provider_intents.size > 1
              all_link_paths = ''
              found_provider_intents.each do |provider_intent|
                all_link_paths = all_link_paths + "\n   #{provider_intent[:original_name]}#{" aliased as '#{provider_intent[:name]}'" unless provider_intent[:name].nil?} (job: #{provider_intent.link_provider[:name]}, instance group: #{provider_intent.link_provider[:instance_group]})"
              end
              raise Bosh::Director::DeploymentInvalidLink, "Multiple providers of name/alias '#{consumer_intent.name}' found for job '#{consumer_intent.link_consumer.name}' and instance group '#{consumer_intent.link_consumer.instance_group}'. All of these match:#{all_link_paths}"
            else
              unless consumer_intent.optional
                raise Bosh::Director::DeploymentInvalidLink, "Can't resolve link '#{consumer_intent.name}' in instance group '#{consumer.instance_group}' on job '#{consumer.name}' in deployment '#{deployment_name}'#{" and network '#{link_network}''" unless link_network.to_s.empty?}."
              end
            end
          else
            if found_provider_intents.size > 1
              all_link_paths = ''
              found_provider_intents.each do |provider_intent|
                all_link_paths = all_link_paths + "\n   Deployment: #{provider_intent.link_provider.deployment.name}, instance group: #{provider_intent.link_provider[:instance_group]}, job: #{provider_intent.link_provider[:name]}, link name/alias: #{provider_intent[:name]}"
              end
              raise Bosh::Director::DeploymentInvalidLink, "Multiple providers of type '#{consumer_intent.type}' found for  job '#{consumer_intent.link_consumer.name}' and instance group '#{consumer_intent.link_consumer.instance_group}. All of these match:#{all_link_paths}"
            else
              unless consumer_intent.optional
                raise Bosh::Director::DeploymentInvalidLink, "Can't find link with type '#{consumer_intent.type}' for instance_group '#{consumer_intent.link_consumer.instance_group}' in deployment '#{deployment_name}'#{" and network '#{link_network}''" unless link_network.to_s.empty?}"
              end
            end
          end
        end

        # provider_intent is either provided or (optional and not provided)
        provider_intent = found_provider_intents.first

        if provider_intent
          link_use_ip_address = consumer_intent_metadata['ip_addresses']
          provider_content = provider_intent.content || '{}'
          link_spec = update_addresses(JSON.parse(provider_content), consumer_intent_metadata['network'], global_use_dns_entry, link_use_ip_address)
          link_content = link_spec.to_json

          find_or_create_link(
            name: consumer_intent.original_name,
            provider_intent: provider_intent,
            consumer_intent: consumer_intent,
            link_content: link_content
          ) unless dry_run

          # TODO LINKS: Eventually remove the stored links from instance group and only rely on database. Otherwise this means we are only using the links model for recreates.
          # instance_group.add_resolved_link(provider_intent.link_provider.name, consumer_intent.original_name, link_spec)
        end
      end
    end

    def get_links_from_deployment(deployment)
      consumers = Bosh::Director::Models::Links::LinkConsumer.where(deployment: deployment).all

      links = {}
      consumers.each do |consumer|
        links[consumer.name] = {}
        consumer.intents.each do |consumer_intent|
          Bosh::Director::Models::Links::Link.where(link_consumer_intent: consumer_intent).all.each do |link|
            next if link.link_content.nil?
            content = JSON.parse(link.link_content)
            links[consumer.name][consumer_intent.original_name] = content
          end
        end
      end

      links
    end

    private

    def get_manual_link_provider_for_consumer(consumer_intent)
      manual_provider = find_provider(
        deployment_model: consumer_intent.link_consumer.deployment,
        instance_group_name: consumer_intent.link_consumer.instance_group,
        name: consumer_intent.link_consumer.name,
        type: 'manual'
      )
      manual_provider&.intents&.select do |provider_intent|
        provider_intent.original_name == consumer_intent.original_name
      end

      # TODO LINKS: Add error checking here. It should never have more than 1 entry. If it does, we probably messed up.
    end

    def update_addresses(link_spec, preferred_network_name, global_use_dns_entry, link_use_ip_address)
      link_spec_copy = Bosh::Common::DeepCopy.copy(link_spec)
      if !link_spec_copy.has_key?('default_network')
        unless link_use_ip_address.nil?
          raise Bosh::Director::LinkLookupError, 'Unable to retrieve default network from provider. Please redeploy provider deployment'
        end

        if preferred_network_name
          link_spec_copy['instances'].each do |instance|
            desired_addresses = instance['addresses']
            raise Bosh::Director::LinkLookupError, "Provider link does not have network: '#{preferred_network_name}'" unless desired_addresses.key?(preferred_network_name)
            instance['address'] = desired_addresses[preferred_network_name]
            log_warning_if_applicable(instance['address'], global_use_dns_entry, instance['name'], instance['id'])
          end
        end
      else
        if link_use_ip_address.nil?
          use_dns_entries = global_use_dns_entry
        else
          use_dns_entries = !link_use_ip_address
        end

        network_name = preferred_network_name || link_spec_copy['default_network']
        link_spec_copy['default_network'] = network_name

        link_spec_copy['instances'].each do |instance|
          if use_dns_entries
            desired_addresses = instance['dns_addresses']
          else
            desired_addresses = instance['addresses']
          end

          raise Bosh::Director::LinkLookupError, "Provider link does not have network: '#{network_name}'" unless desired_addresses.key?(network_name)

          instance['address'] = desired_addresses[network_name]
          log_warning_if_applicable(instance['address'], use_dns_entries, instance['name'], instance['id'])
        end
      end

      link_spec_copy['instances']&.each do |instance|
        instance.delete('addresses')
        instance.delete('dns_addresses')
      end

      link_spec_copy
    end

    def log_warning_if_applicable(address, dns_required, instance_name, instance_id)
      if dns_required && ip_address?(address)
        message = "DNS address not available for the link provider instance: #{instance_name}/#{instance_id}"
        @logger.warn(message)
        # TODO LINKS: Add event logger?
        # @event_logger.warn(message)
      elsif !dns_required && !ip_address?(address)
        message = "IP address not available for the link provider instance: #{instance_name}/#{instance_id}"
        @logger.warn(message)
        # @event_logger.warn(message)
      end
    end

  end
end