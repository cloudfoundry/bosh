module Bosh::Director
  module DeploymentPlan
    class LinksResolver
      include IpUtil

      def initialize(deployment_plan, logger)
        @deployment_plan = deployment_plan
        @logger = logger
        @event_log = Config.event_log
        @links_manager = Bosh::Director::Links::LinksManager.new()
      end

      def add_providers(instance_group)
        @logger.debug("Adding link providers for instance group '#{instance_group.name}'")

        instance_group.jobs.each do |job|
          add_provided_links(instance_group, job)
        end
        add_unmanaged_disk_providers(instance_group)
      end

      def resolve(instance_group)
        @logger.debug("Resolving links for instance group '#{instance_group.name}'")

        instance_group.jobs.each do |job|
          resolve_consumed_links(instance_group, job)
          ensure_all_links_in_consumes_block_are_mentioned_in_spec(instance_group, job)
        end
      end

      private

      def resolve_consumed_links(instance_group, job)
        consumer = @links_manager.find_consumer(
          deployment_model: @deployment_plan.model,
          instance_group_name: instance_group.name,
          name: job.name,
          type: 'job'
        )

        if consumer&.intents
          consumer.intents.each do |consumer_intent|
            #TODO LINKS: Double check logic in fulfill_explicit/implicit_links -> ... if found_providers are 0 and consumer is optional. Should we raise exception or continue silently?
            consumer_intent_metadata = {}
            consumer_intent_metadata = JSON.parse(consumer_intent.metadata) unless consumer_intent.metadata.nil?
            if consumer_intent.name
              from_deployment = consumer_intent_metadata['from_deployment'] || consumer.deployment
              provider_intent = fulfill_explicit_link(consumer_intent.name, consumer_intent_metadata['network'], from_deployment, consumer_intent)
              create_link(consumer_intent, consumer_intent_metadata, instance_group, job, provider_intent)
            else
              provider_intents = get_manual_link_provider_for_consumer(consumer_intent)
              if provider_intents && provider_intents.size == 1
                provider_intent = provider_intents.first
                @links_manager.find_or_create_link(
                  name: consumer_intent.original_name,
                  provider_intent: provider_intent,
                  consumer_intent: consumer_intent,
                  link_content: provider_intent.contents
                )
              else
                provider_intent = fulfill_implicit_link(consumer_intent.type, consumer_intent_metadata['network'], consumer_intent)
                create_link(consumer_intent, consumer_intent_metadata, instance_group, job, provider_intent)
              end
            end
          end
        end
      end

      def create_link(consumer_intent, consumer_intent_metadata, instance_group, job, provider_intent)
        # If provider_intent is nil and no exception was raised by now, it must be optional so don't raise anything here
        if provider_intent
          link_use_ip_address = consumer_intent_metadata['ip_addresses']

          link_spec = update_addresses(JSON.parse(provider_intent[:content]), consumer_intent_metadata['network'], @deployment_plan.use_dns_addresses?, link_use_ip_address)

          instance_group.add_resolved_link(job.name, consumer_intent.name, link_spec)

          link_content = link_spec.to_json

          @links_manager.find_or_create_link(
            name: consumer_intent.original_name,
            provider_intent: provider_intent,
            consumer_intent: consumer_intent,
            link_content: link_content
          )
        end
      end

      def get_manual_link_provider_for_consumer(consumer_intent)
        manual_provider = @links_manager.find_provider(
          deployment_model: consumer_intent.consumer.deployment,
          instance_group_name: consumer_intent.consumer.instance_group,
          name: consumer_intent.consumer.name,
          type: 'manual'
        )
        manual_provider.intents.select do |provider_intent|
          provider_intent.original_name == consumer_intent.original_name
        end
      end

      def fulfill_explicit_link(link_from_name, link_network, from_deployment, consumer_intent)
        if from_deployment.nil? || from_deployment == @deployment_plan.name
          get_link_path_from_deployment_plan(link_from_name, link_network, consumer_intent)
        else
          find_deployment_and_get_link_path(from_deployment, link_from_name, link_network, consumer_intent)
        end
      end

      def fulfill_implicit_link(link_type, link_network, consumer_intent)
        found_provider_intents = []
        found_providers = @links_manager.find_providers(deployment: @deployment_plan)
        found_providers.each do |provider|
          if instance_group_has_link_network(provider.instance_group, link_network)
            provider.intents&.each do |provider_intent|
              found_provider_intents << provider_intent if provider_intent[:type] == link_type
            end
          end
        end

        if found_provider_intents.size == 1
          return found_provider_intents.first
        elsif found_provider_intents.size > 1
          all_link_paths = ''
          found_provider_intents.each do |provider_intent|
            all_link_paths = all_link_paths + "\n   #{provider_intent.provider[:deployment]}.#{provider_intent.provider[:instance_group]}.#{provider_intent.provider[:name]}.#{provider_intent[:name]}"
          end
          raise "Multiple instance groups provide links of type '#{link_type}'. Cannot decide which one to use for instance group '#{consumer_intent.consumer.instance_group}'.#{all_link_paths}"
        else
          # Only raise an exception if no linkpath was found, and the link is not optional
          unless consumer_intent.optional
            raise "Can't find link with type '#{link_type}' for instance_group '#{consumer_intent.consumer.instance_group}' in deployment '#{@deployment_plan.name}'#{" and network '#{link_network}''" unless link_network.to_s.empty?}"
          end
        end
      end

      def ensure_all_links_in_consumes_block_are_mentioned_in_spec(instance_group, job)
        return if instance_group.link_paths.empty?
        instance_group.link_paths[job.name].to_a.each do |link_name, _|
          unless job.model_consumed_links.map(&:name).include?(link_name)
            raise Bosh::Director::UnusedProvidedLink,
                  "Job '#{job.name}' in instance group '#{instance_group.name}' specifies link '#{link_name}', " +
                    'but the release job does not consume it.'
          end
        end
      end

      def instance_group_has_link_network(instance_group, link_network)
        !link_network || instance_group.has_network?(link_network)
      end

      def get_link_path_from_deployment_plan(from_name, link_network, consumer_intent)
        found_provider_intents = []
        found_providers = @links_manager.find_providers(deployment: @deployment_plan)
        found_providers.each do |provider|
          if instance_group_has_link_network(provider.instance_group, link_network)
            provider.intents&.each do |provider_intent|
              found_provider_intents << provider_intent if provider_intent[:name] == from_name
            end
          end
        end

        if found_provider_intents.size == 1
          return found_provider_intents.first
        elsif found_provider_intents.size > 1
          all_link_paths = ''
          found_provider_intents.each do |provider_intent|
            all_link_paths = all_link_paths + "\n   #{provider_intent[:original_name]}#{" aliased as '#{provider_intent[:name]}'" unless provider_intent[:name].nil?} (job: #{provider_intent.provider[:name]}, instance group: #{provider_intent.provider[:instance_group]})"
          end
          raise "Cannot resolve ambiguous link '#{from_name}' (job: #{consumer_intent.consumer.name}, instance group: #{consumer_intent.consumer.instance_group}). All of these match: #{all_link_paths}"
        else
          unless consumer_intent.optional
            raise "Can't resolve link '#{from_name}' in instance group '#{consumer_intent.consumer.instance_group}' on job '#{consumer_intent.consumer.name}' in deployment '#{@deployment_plan.name}'#{" and network '#{link_network}'" unless link_network.to_s.empty?}."
          end
        end
      end

      def find_deployment_and_get_link_path(deployment_name, alias_name, link_network, consumer_intent)
        deployment = Models::Deployment.find(name: deployment_name)
        if !deployment
          raise "Can't find deployment #{deployment_name}"
        end

        # get the link path from that deployment
        found_provider_intents = []
        found_providers = @links_manager.find_providers(deployment: deployment)
        found_providers.each do |provider|
          provider.intents&.each do |provider_intent|
            provider_intent_networks = JSON.parse(provider_intent.content)&['networks']
            #TODO LINKS: Optimize here and 3000 other places - query DB by these params and not by deployment first
            if provider_intent[:name] == alias_name && provider_intent.shared && (!link_network || provider_intent_networks.include?(link_network))
              found_provider_intents << provider_intent
            end
          end
        end

        if found_provider_intents.size == 1
          return found_provider_intents.first
        elsif found_provider_intents.size > 1
          all_link_paths = ''
          found_provider_intents.each do |provider_intent|
            all_link_paths = all_link_paths + "\n   #{provider_intent.provider[:deployment]}.#{provider_intent.provider[:instance_group]}.#{provider_intent.provider[:name]}.#{alias_name}"
          end
          link_str = "#{@deployment_plan.name}.#{consumer_intent.consumer.instance_group}.#{consumer_intent.consumer.name}.#{consumer_intent.name}"
          raise "Cannot resolve ambiguous link '#{link_str}' in deployment #{deployment.name}:#{all_link_paths}"
        else
          unless consumer_intent.optional
            raise "Can't resolve link '#{alias_name}' in instance group '#{@consumer_intent.consumer.instance_group}' on job '#{@consumer_intent.consumer.name}' in deployment '#{@consumer_intent.consumer.deployment}'#{" and network '#{link_network}''" unless link_network.to_s.empty?}. Please make sure the link was provided and shared."
          end
        end
      end

      def add_unmanaged_disk_providers(instance_group)
        instance_group.persistent_disk_collection.non_managed_disks.each do |disk|
          provider = @links_manager.find_or_create_provider(
            deployment_model: @deployment_plan.model,
            instance_group_name: instance_group.name,
            name: instance_group.name,
            type: 'instance_group'
          )

          provider_intent = @links_manager.find_or_create_provider_intent(
            link_provider: provider,
            link_original_name: disk.name,
            link_type: 'disk'
          )

          provider_intent.shared = false
          provider_intent.name = disk.name
          provider_intent.content = DiskLink.new(@deployment_plan.name, disk.name).spec.to_json
          provider_intent.save

          @deployment_plan.add_link_provider(provider)
        end
      end

      def add_provided_links(instance_group, job)
        providers = @links_manager.find_providers(deployment: @deployment_plan.model)
        providers.each do |provider|
          provider.intents.each do |provider_intent|
            metadata = {}
            metadata = JSON.parse(provider_intent.metadata) unless provider_intent.metadata.nil?
            provider_intent.content = Link.new(instance_group.deployment_name, instance_group, job, metadata['mapped_properties']).spec.to_json
            provider_intent.save
          end
        end
        # job.provided_links(instance_group.name).each do |provided_link|
        #   provider = @links_manager.find_or_create_provider(
        #     deployment_model: @deployment_plan.model,
        #     instance_group_name: instance_group.name,
        #     name: job.name,
        #     type: 'job'
        #   )
        #
        #   provider_intent = @links_manager.find_or_create_provider_intent(
        #     link_provider: provider,
        #     link_original_name: provided_link.original_name,
        #     link_type: provided_link.type
        #   )
        #
        #   provider_intent.shared = provided_link.shared
        #   provider_intent.name = provided_link.name
        #   provider_intent.content = Link.new(instance_group.deployment_name, provided_link.name, instance_group, job).spec.to_json
        #   provider_intent.save
        #
        #   @deployment_plan.add_link_provider(provider)
        # end
      end

      def update_addresses(link_spec, preferred_network_name, global_use_dns_entry, link_use_ip_address)
        link_spec_copy = Bosh::Common::DeepCopy.copy(link_spec)
        if !link_spec_copy.has_key?('default_network')
          if !link_use_ip_address.nil?
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

        link_spec_copy['instances'].each do |instance|
          instance.delete('addresses')
          instance.delete('dns_addresses')
        end

        link_spec_copy
      end

      def log_warning_if_applicable(address, dns_required, instance_name, instance_id)
        if dns_required && ip_address?(address)
          message = "DNS address not available for the link provider instance: #{instance_name}/#{instance_id}"
          @logger.warn(message)
          @event_log.warn(message)
        elsif !dns_required && !ip_address?(address)
          message = "IP address not available for the link provider instance: #{instance_name}/#{instance_id}"
          @logger.warn(message)
          @event_log.warn(message)
        end
      end
    end
  end
end
