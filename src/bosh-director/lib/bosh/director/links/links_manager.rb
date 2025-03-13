module Bosh::Director::Links
  class LinksManager
    include Bosh::Director::IpUtil

    def initialize(serial_id, logger = Bosh::Director::Config.logger, event_logger = Bosh::Director::Config.event_log)
      @logger = logger
      @event_logger = event_logger
      @serial_id = serial_id
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
        type: type,
      ).tap do |result|
        if result.serial_id != @serial_id
          result.serial_id = @serial_id
          result.save
        end
      end
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
        type: type,
        serial_id: @serial_id,
      )
    end

    # Used by provider, not using alias because want to update existing provider intent when alias changes
    def find_or_create_provider_intent(link_provider:, link_original_name:, link_type:)
      intent = Bosh::Director::Models::Links::LinkProviderIntent.find(
        link_provider: link_provider,
        original_name: link_original_name,
      )

      if intent.nil?
        intent = Bosh::Director::Models::Links::LinkProviderIntent.create(
          link_provider: link_provider,
          original_name: link_original_name,
          type: link_type,
        )
      else
        intent.type = link_type
      end

      intent.serial_id = @serial_id if intent.serial_id != @serial_id
      intent.save
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
        type: type,
      ).tap do |result|
        if result.serial_id != @serial_id
          result.serial_id = @serial_id
          result.save
        end
      end
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
        type: type,
        serial_id: deployment_model.links_serial_id,
      )
    end

    def find_or_create_consumer_intent(
      link_consumer:,
      link_original_name:,
      link_type:,
      new_intent_metadata:
    )
      intent = Bosh::Director::Models::Links::LinkConsumerIntent.find(
        link_consumer: link_consumer,
        original_name: link_original_name,
      )

      if intent.nil?
        intent = Bosh::Director::Models::Links::LinkConsumerIntent.create(
          link_consumer: link_consumer,
          original_name: link_original_name,
          type: link_type,
          metadata: new_intent_metadata.to_json,
        )
      else
        intent.metadata = new_intent_metadata.nil? ? nil : new_intent_metadata.to_json
        intent.type = link_type
      end

      intent.serial_id = @serial_id
      intent.save
    end

    def find_or_create_link(
      name:,
      provider_intent:,
      consumer_intent:,
      link_content:
    )
      found_link = nil
      found_links = Bosh::Director::Models::Links::Link.where(
        link_provider_intent_id: provider_intent && provider_intent[:id],
        link_consumer_intent_id: consumer_intent && consumer_intent[:id],
      )

      found_links&.each do |link|
        db_content = JSON.parse(link.link_content)
        new_content = JSON.parse(link_content)
        if are_equal(db_content, new_content)
          found_link = link
          break
        end
      end

      unless found_link
        return Bosh::Director::Models::Links::Link.create(
          name: name,
          link_provider_intent_id: provider_intent && provider_intent[:id],
          link_consumer_intent_id: consumer_intent && consumer_intent[:id],
          link_content: link_content,
        )
      end

      found_link
    end

    def resolve_deployment_links(deployment_model, options)
      dry_run = options.fetch(:dry_run, false)
      global_use_dns_entry = options.fetch(:global_use_dns_entry)

      links_consumers = deployment_model.link_consumers
      return if links_consumers.empty?

      errors = []

      links_consumers.each do |consumer|
        next if consumer.serial_id != @serial_id
        consumer.intents.each do |consumer_intent|
          next if consumer_intent.serial_id != @serial_id
          begin
            resolve_consumer_intent_and_generate_link(consumer_intent, global_use_dns_entry, dry_run)
          rescue => e
            errors.push e.message
          end
        end
      end

      unless errors.empty?
        message = "Failed to resolve links from deployment '#{deployment_model.name}'. See errors below:\n  - "
        message += errors.join("\n  - ")
        raise message
      end
    end

    def get_links_from_deployment(deployment)
      consumers = Bosh::Director::Models::Links::LinkConsumer.where(deployment: deployment).all

      links = {}
      consumers.each do |consumer|
        links[consumer.name] = {}
        consumer.intents.each do |consumer_intent|
          consumer_intent.links.each do |link|
            next if link.link_content.nil?
            content = JSON.parse(link.link_content)
            links[consumer.name][consumer_intent.original_name] = content
          end
        end
      end

      links
    end

    def get_link_provider_intents_for_deployment(deployment)
      Bosh::Director::Models::Links::LinkProviderIntent .where(
        serial_id: deployment.links_serial_id,
        link_provider: Bosh::Director::Models::Links::LinkProvider.where(deployment: deployment),
      ).all
    end

    def get_links_for_instance_group(deployment_model, instance_group_name)
      links = {}
      consumers = Bosh::Director::Models::Links::LinkConsumer.where(deployment: deployment_model, instance_group: instance_group_name, serial_id: deployment_model.links_serial_id)

      consumers.each do |consumer|
        links[consumer.name] = {}
        consumer.intents.each do |consumer_intent|
          next if consumer.serial_id != consumer_intent.serial_id

          link = Bosh::Director::Models::Links::Link.where(id: consumer_intent.target_link_id).first
          next if link.nil?
          next if !link.link_provider_intent.nil? &&
                  link.link_provider_intent.link_provider.deployment_id == deployment_model.id &&
                  link.link_provider_intent.serial_id != consumer_intent.serial_id
          next if link.link_consumer_intent.blocked
          next unless link.link_provider_intent.nil? || link.link_provider_intent.consumable

          content = JSON.parse(link.link_content)
          content['group_name'] = link.group_name

          links[consumer.name][link.name] = content
        end
      end

      links
    end

    def get_links_for_instance(instance)
      return get_links_for_instance_group(instance.deployment_model, instance.instance_group_name) if instance.is_deploy_action?

      links = {}

      newest_instance_link = Bosh::Director::Models::Links::InstancesLink.where(instance_id: instance.model.id).order(Sequel.desc(:serial_id)).first
      instance_links = Bosh::Director::Models::Links::InstancesLink.where(instance_id: instance.model.id)

      instance_links.each do |instance_link|
        next if instance_link.serial_id < newest_instance_link.serial_id

        link = instance_link.link
        consumer_intent = link.link_consumer_intent
        consumer = consumer_intent.link_consumer

        content = JSON.parse(link.link_content)
        content['group_name'] = link.group_name

        links[consumer.name] ||= {}
        links[consumer.name][consumer_intent.original_name] = content
      end

      links
    end

    def bind_links_to_instance(instance)
      consumers = Bosh::Director::Models::Links::LinkConsumer.where(deployment: instance.deployment_model, instance_group: instance.instance_group_name)

      instance_model = instance.model
      consumers.each do |consumer|
        next if consumer.serial_id != instance.deployment_model.links_serial_id
        consumer.intents.each do |consumer_intent|
          next if consumer_intent.serial_id != instance.deployment_model.links_serial_id
          next if consumer_intent.links.empty?

          target_link = Bosh::Director::Models::Links::Link.where(id: consumer_intent.target_link_id).first

          next if !target_link.link_provider_intent.nil? &&
                  target_link.link_provider_intent.link_provider.deployment_id == instance.deployment_model.id &&
                  target_link.link_provider_intent.serial_id != consumer_intent.serial_id

          next if target_link.link_consumer_intent.blocked
          next unless target_link.link_provider_intent.nil? || target_link.link_provider_intent.consumable

          instance_link = Bosh::Director::Models::Links::InstancesLink.where(instance_id: instance.model.id,
                                                                             link_id: target_link.id).first
          if instance_link.nil?
            instance_model.add_link(target_link)
            instance_link = Bosh::Director::Models::Links::InstancesLink.where(instance_id: instance.model.id,
                                                                               link_id: target_link.id).first
          end
          if instance_link.serial_id != @serial_id
            instance_link.serial_id = @serial_id
            instance_link.save
          end
        end
      end
    end

    def update_provider_intents_contents(link_providers, deployment_plan)
      link_providers.select { |provider| provider.type == 'job' && provider.serial_id == deployment_plan.model.links_serial_id }.each do |provider|
        instance_group = deployment_plan.instance_group(provider.instance_group)
        provider.intents.each do |provider_intent|
          next if provider_intent.serial_id != deployment_plan.model.links_serial_id
          next unless consumer?(provider_intent, deployment_plan)
          metadata = {}
          metadata = JSON.parse(provider_intent.metadata) unless provider_intent.metadata.nil?

          properties = metadata['mapped_properties']

          content = Bosh::Director::DeploymentPlan::Link.new(
            provider.deployment.name,
            provider_intent.name,
            provider_intent.type,
            instance_group,
            properties,
            deployment_plan.use_dns_addresses?,
            deployment_plan.use_short_dns_addresses?,
            deployment_plan.use_link_dns_names?,
          ).spec.to_json
          provider_intent.content = content
          provider_intent.save
        end
      end
    end

    def remove_unused_links(deployment_model)
      serial_id = deployment_model.links_serial_id

      deployment_model.link_providers.each do |provider|
        provider.intents.each do |provider_intent|
          provider_intent.delete unless provider_intent.serial_id == serial_id
        end
        provider.delete unless provider.serial_id == serial_id
      end

      deployment_model.link_consumers.each do |consumer|
        next if consumer.type == 'external'
        consumer.intents.each do |consumer_intent|
          if consumer_intent.serial_id == serial_id
            Bosh::Director::Models::Links::Link.where(link_consumer_intent: consumer_intent).each do |link|
              if consumer.type == 'job'
                instances_links = Bosh::Director::Models::Links::InstancesLink.where(
                  link_id: link.id,
                  serial_id: consumer_intent.serial_id,
                )
                link.delete if instances_links.count.zero?
              elsif consumer.type == 'variable'
                newest_link = Bosh::Director::Models::Links::Link.where(
                  link_consumer_intent_id: consumer_intent.id,
                ).order(Sequel.desc(:id)).first
                link.delete if link.id != newest_link.id
              end
            end
          else
            consumer_intent.destroy
          end
        end
        consumer.destroy unless consumer.serial_id == serial_id
      end
    end

    def resolve_consumer_intent_and_generate_link(consumer_intent, global_use_dns_entry, dry_run, external_provider_intent = nil)
      consumer_intent_metadata = {}
      consumer_intent_metadata = JSON.parse(consumer_intent.metadata) unless consumer_intent.metadata.nil?
      is_manual_link = !!consumer_intent_metadata['manual_link']

      if is_manual_link
        provider_intent = get_manual_link_provider_for_consumer(consumer_intent)
        link_content = provider_intent.content || '{}'

        unless dry_run
          link = find_or_create_link(
            name: consumer_intent.original_name,
            provider_intent: provider_intent,
            consumer_intent: consumer_intent,
            link_content: link_content,
          )
          consumer_intent.target_link_id = link.id
          consumer_intent.save
          link
        end
      else
        if external_provider_intent.nil?
          found_provider_intents = provider_intents_for_consumer_intent(consumer_intent, consumer_intent_metadata)
        else
          found_provider_intents = [external_provider_intent]
        end

        link_network = consumer_intent_metadata['network']
        is_explicit_link = !!consumer_intent_metadata['explicit_link']

        if found_provider_intents.empty? && consumer_intent.optional
          return unless is_explicit_link && !consumer_intent.blocked
        end

        validate_found_providers(found_provider_intents, consumer_intent, link_network)

        unless dry_run
          provider_intent = found_provider_intents.first

          validate_provider_with_explicit_link(
            consumer_intent, found_provider_intents, is_explicit_link, link_network, provider_intent
          )

          link_content = extract_provider_link_content(consumer_intent_metadata, global_use_dns_entry, link_network, provider_intent)

          link = find_or_create_link(
            name: consumer_intent.original_name,
            provider_intent: provider_intent,
            consumer_intent: consumer_intent,
            link_content: link_content,
          )
          consumer_intent.target_link_id = link.id
          consumer_intent.save
          link
        end
      end
    end

    def migrate_links_provider_instance_group(deployment_model, instance_group_model)
      instance_group_list = instance_group_model.migrated_from.map { |h| h['name'] }

      instance_group_list.each do |instance_group_name|
        deployment_model.link_providers.each do |link_provider|
          next if link_provider.instance_group != instance_group_name
          if link_provider.serial_id == deployment_model.links_serial_id
            link_provider.instance_group = instance_group_model.name
            link_provider.save
          end
        end
      end
    end

    def migrate_links_consumer_instance_group(deployment_model, instance_group_model)
      instance_group_list = instance_group_model.migrated_from.map { |h| h['name'] }

      instance_group_list.each do |instance_group_name|
        deployment_model.link_consumers.each do |link_consumer|
          next if link_consumer.instance_group != instance_group_name
          if link_consumer.serial_id == deployment_model.links_serial_id
            link_consumer.instance_group = instance_group_model.name
            link_consumer.save
          end
        end
      end
    end

    private

    def validate_provider_with_explicit_link(
      consumer_intent, found_provider_intents, is_explicit_link, link_network, provider_intent
    )
      return unless is_explicit_link

      content = provider_intent.content || '{}'
      provider_intent_networks = JSON.parse(content)['networks']

      return unless link_network && (provider_intent_networks.nil? || !provider_intent_networks.include?(link_network))

      raise Bosh::Director::DeploymentInvalidLink, Bosh::Director::Links::LinksErrorBuilder.build_link_error(
        consumer_intent, found_provider_intents, link_network
      )
    end

    # A consumer which is within the same deployment
    def consumer?(provider_intent, deployment_plan)
      return true if provider_intent.shared

      link_consumers = deployment_plan.model.link_consumers
      link_consumers = link_consumers.select do |consumer|
        consumer.serial_id == @serial_id
      end

      link_consumers.any? do |consumer|
        consumer.intents.any? do |consumer_intent|
          can_be_consumed?(consumer, provider_intent, consumer_intent, @serial_id)
        end
      end
    end

    def can_be_consumed?(consumer, provider_intent, consumer_intent, serial_id)
      consumer_intent_metadata = JSON.parse(consumer_intent.metadata || '{}')

      !consumer_intent.blocked &&
        consumer_intent.serial_id == serial_id &&
        provider_intent.type == consumer_intent.type &&
        !cross_deployment?(consumer, consumer_intent_metadata) &&
        explict_link_matching?(consumer_intent_metadata, provider_intent, consumer_intent)
    end

    def explict_link_matching?(metadata, provider_intent, consumer_intent)
      !metadata['explicit_link'] || provider_intent.name == consumer_intent.name
    end

    def cross_deployment?(consumer, consumer_intent_metadata)
      deployment_name = consumer_intent_metadata['from_deployment'] || consumer.deployment.name
      consumer.deployment.name != deployment_name
    end

    def extract_provider_link_content(consumer_intent_metadata, global_use_dns_entry, link_network, provider_intent)
      link_use_ip_address = consumer_intent_metadata['ip_addresses']
      provider_content = provider_intent.content || '{}'
      # determine what network name / dns entry things to use
      link_spec = update_addresses(JSON.parse(provider_content), link_network, global_use_dns_entry, link_use_ip_address)
      link_spec.to_json
    end

    def provider_intents_for_consumer_intent(consumer_intent, consumer_intent_metadata)
      consumer = consumer_intent.link_consumer
      found_provider_intents = []

      unless consumer_intent.blocked
        deployment_name = consumer_intent_metadata['from_deployment'] || consumer.deployment.name
        is_cross_deployment = (consumer.deployment.name != deployment_name)

        if is_cross_deployment
          deployment = Bosh::Director::Models::Deployment.find(name: deployment_name)
          raise Bosh::Director::DeploymentNotFound, "Can't find deployment '#{deployment_name}'" if deployment.nil?
        else
          deployment = consumer.deployment
        end

        providers = deployment.link_providers

        is_explicit_link = !!consumer_intent_metadata['explicit_link']

        providers.each do |provider|
          next if provider.type == 'manual'
          provider.intents.each do |provider_intent|
            next if provider_intent.type != consumer_intent.type

            if is_explicit_link
              next if provider_intent.name != consumer_intent.name
              next if is_cross_deployment && !provider_intent.shared
            end

            next if provider_intent.serial_id != deployment.links_serial_id
            next unless provider_intent.consumable
            found_provider_intents << provider_intent
          end
        end
      end
      found_provider_intents
    end

    def get_manual_link_provider_for_consumer(consumer_intent)
      consumer_name = consumer_intent.link_consumer.name
      consumer_instance_group = consumer_intent.link_consumer.instance_group
      consumer_intent_name = consumer_intent.original_name

      manual_provider = find_provider(
        deployment_model: consumer_intent.link_consumer.deployment,
        instance_group_name: consumer_instance_group,
        name: consumer_name,
        type: 'manual',
      )

      error_msg = "Failed to find manual link provider for consumer '#{consumer_intent_name}' in job '#{consumer_name}' in instance group '#{consumer_intent_name}'"
      raise error_msg if manual_provider.nil?

      manual_provider_intent = manual_provider.find_intent_by_name(consumer_intent_name)
      raise error_msg if manual_provider_intent.nil?

      manual_provider_intent
    end

    def update_addresses(provider_intent_content, preferred_network_name, global_use_dns_entry, link_use_ip_address)
      provider_intent_content_copy = Bosh::Director::DeepCopy.copy(provider_intent_content)
      provider_dns_enabled = provider_intent_content_copy['use_dns_addresses']
      if !provider_intent_content_copy.key?('default_network')
        unless link_use_ip_address.nil?
          raise Bosh::Director::LinkLookupError, 'Unable to retrieve default network from provider. Please redeploy provider deployment'
        end

        if preferred_network_name
          provider_intent_content_copy['instances'].each do |instance|
            desired_addresses = instance['addresses']
            raise Bosh::Director::LinkLookupError, "Provider link does not have network: '#{preferred_network_name}'" unless desired_addresses.key?(preferred_network_name)
            instance['address'] = desired_addresses[preferred_network_name]
            log_warning_if_applicable(instance['address'], global_use_dns_entry, instance['name'], instance['id'])
          end
        end
      else
        network_name = preferred_network_name || provider_intent_content_copy['default_network']
        provider_intent_content_copy['default_network'] = network_name

        provider_intent_content_copy['instances'].each do |instance|
          if link_use_ip_address.nil?
            desired_addresses = provider_dns_enabled ? instance['dns_addresses'] : instance['addresses']
          else
            desired_addresses = link_use_ip_address ? instance['addresses'] : instance['dns_addresses']
            global_use_dns_entry = !link_use_ip_address
          end

          raise Bosh::Director::LinkLookupError, "Provider link does not have network: '#{network_name}'" unless desired_addresses.key?(network_name)

          instance['address'] = desired_addresses[network_name]
          log_warning_if_applicable(instance['address'], global_use_dns_entry, instance['name'], instance['id'])
        end
      end

      provider_intent_content_copy['instances']&.each do |instance|
        instance.delete('addresses')
        instance.delete('dns_addresses')
      end

      provider_intent_content_copy
    end

    def validate_found_providers(found_provider_intents, consumer_intent, link_network)
      raise Bosh::Director::DeploymentInvalidLink, Bosh::Director::Links::LinksErrorBuilder.build_link_error(consumer_intent, found_provider_intents, link_network) if found_provider_intents.size != 1
    end

    def log_warning_if_applicable(address, dns_required, instance_name, instance_id)
      if dns_required && ip_address?(address)
        message = "DNS address not available for the link provider instance: #{instance_name}/#{instance_id}"
        @logger.warn(message)
        @event_logger.warn(message)
      end
    end

    def are_equal(content1, content2)
      content1.all? do |key, value|
        next value.sort == content2[key].sort if key == 'networks'
        next value.sort_by { |i| i['id'] } == content2[key].sort_by { |i| i['id'] } if key == 'instances'

        value == content2[key]
      end
    end
  end
end
