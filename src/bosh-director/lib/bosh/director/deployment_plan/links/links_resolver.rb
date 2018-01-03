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
        job.model_consumed_links.each do |consumed_link|
          consumer = @links_manager.find_or_create_consumer(
            deployment_model: @deployment_plan.model,
            instance_group_name: instance_group.name,
            name: job.name,
            type: 'job'
          )

          consumer_intent = @links_manager.find_or_create_consumer_intent(
            link_consumer: consumer,
            original_link_name: consumed_link.original_name,
            link_type: consumed_link.type,
            optional: consumed_link.optional,
            blocked: false
          )

          consumer_intent.name = consumed_link.name
          consumer_intent.save

          @deployment_plan.add_link_consumer(consumer)

          link_name = consumed_link.name

          provider_intent = nil

          link_path = instance_group.link_path(job.name, link_name)
          if link_path.nil?
            # Only raise an exception when the link_path is nil, and it is not optional
            if !consumed_link.optional
              raise JobMissingLink, "Link path was not provided for required link '#{link_name}' in instance group '#{instance_group.name}'"
            end
            next
          elsif !link_path.manual_spec.nil?
            instance_group.add_resolved_link(job.name, link_name, link_path.manual_spec)
            link_content = link_path.manual_spec.to_json
          else
            provider_deployment = Models::Deployment[name: link_path.deployment]

            provider = @links_manager.find_provider(
              deployment_model: provider_deployment,
              instance_group_name: link_path.instance_group,
              name: link_path.owner
            )

            provider_intent = @links_manager.find_provider_intent_by_alias(
              link_provider: provider,
              link_alias: link_path.name,
              link_type: consumed_link.type,
            )

            if provider_intent.nil?
              raise DeploymentInvalidLink, "Cannot resolve link path '#{link_path}' required for link '#{link_name}' in instance group '#{instance_group.name}' on job '#{job.name}'"
            end

            link_info = job.consumes_link_info(instance_group.name, link_name)
            link_use_ip_address = link_info.has_key?('ip_addresses') ? link_info['ip_addresses'] : nil

            link_spec = update_addresses(JSON.parse(provider_intent[:content]), link_info['network'], @deployment_plan.use_dns_addresses?, link_use_ip_address)

            instance_group.add_resolved_link(job.name, link_name, link_spec)

            link_content = link_spec.to_json
          end

          @links_manager.find_or_create_link(
            name: consumed_link.original_name,
            provider_intent: provider_intent,
            consumer_intent: consumer_intent,
            link_content: link_content
          )
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
        job.provided_links(instance_group.name).each do |provided_link|
          provider = @links_manager.find_or_create_provider(
            deployment_model: @deployment_plan.model,
            instance_group_name: instance_group.name,
            name: job.name,
            type: 'job'
          )

          provider_intent = @links_manager.find_or_create_provider_intent(
            link_provider: provider,
            link_original_name: provided_link.original_name,
            link_type: provided_link.type
          )

          provider_intent.shared = provided_link.shared
          provider_intent.name = provided_link.name
          provider_intent.content = Link.new(instance_group.deployment_name, provided_link.name, instance_group, job).spec.to_json
          provider_intent.save

          @deployment_plan.add_link_provider(provider)
        end
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
