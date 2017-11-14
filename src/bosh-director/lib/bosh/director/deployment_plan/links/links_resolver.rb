module Bosh::Director
  module DeploymentPlan
    class LinksResolver
      def initialize(deployment_plan, logger)
        @deployment_plan = deployment_plan
        @logger = logger
      end

      def resolve(instance_group)
        @logger.debug("Resolving links for instance group '#{instance_group.name}'")

        instance_group.jobs.each do |job|
          resolve_consumed_links(instance_group, job)
          ensure_all_links_in_consumes_block_are_mentioned_in_spec(instance_group, job)
          add_provided_links(instance_group, job)
        end
      end

      def apply(instance_group)
        @logger.debug("Applying links for instance group '#{instance_group.name}'")

        instance_group.jobs.each do |job|
          add_consumed_links(instance_group, job)
        end
      end

      private

      def resolve_consumed_links(instance_group, job)
        job.model_consumed_links.each do |consumed_link|
          link_name = consumed_link.name

          link_path = instance_group.link_path(job.name, link_name)
          if link_path.nil?
            # Only raise an exception when the link_path is nil, and it is not optional
            if !consumed_link.optional
              raise JobMissingLink, "Link path was not provided for required link '#{link_name}' in instance group '#{instance_group.name}'"
            end
          elsif !link_path.manual_spec.nil?
            instance_group.add_resolved_link(job.name, link_name, link_path.manual_spec)
          else
            link_info = job.consumes_link_info(instance_group.name, link_name)

            preferred_network_name = link_info['network']
            link_use_ip_address = link_info.has_key?('ip_addresses') ? link_info['ip_addresses'] : nil

            link_network_options = {
              :preferred_network_name => preferred_network_name,
              :global_use_dns_entry => @deployment_plan.use_dns_addresses?,
              :link_use_ip_address => link_use_ip_address
            }

            link_lookup = LinkLookupFactory.create(consumed_link, link_path, @deployment_plan, link_network_options)
            link_spec = link_lookup.find_link_provider

            unless link_spec
              raise DeploymentInvalidLink, "Cannot resolve link path '#{link_path}' required for link '#{link_name}' in instance group '#{instance_group.name}' on job '#{job.name}'"
            end

            link_spec['instances'].each do |instance|
              instance.delete('addresses')
              instance.delete('dns_addresses')
            end

            instance_group.add_resolved_link(job.name, link_name, link_spec)
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

      def add_provided_links(instance_group, job)
        job.provided_links(instance_group.name).each do |provided_link|
          link_spec = Link.new(instance_group.deployment_name, provided_link.name, instance_group, job).spec

          provider = Bosh::Director::Models::LinkProvider.find(deployment: @deployment_plan.model, instance_group: instance_group.name, name: provided_link.name, owner_object_name: job.name)

          if provided_link.original_name.nil?
            link_definition_name = provided_link.name
          else
            link_definition_name = provided_link.original_name
          end

          if provider.nil?
            provider = Bosh::Director::Models::LinkProvider.new(
              deployment: @deployment_plan.model,
              instance_group: instance_group.name,
              name: provided_link.name,
              consumable: true,
              shared: provided_link.shared,
              owner_object_name: job.name,
              owner_object_type: 'Job',
              link_provider_definition_name: link_definition_name,
            )
          end
          provider.content = link_spec.to_json
          provider.shared = provided_link.shared
          provider.link_provider_definition_type = provided_link.type
          provider.link_provider_definition_name = link_definition_name
          provider.save

          @deployment_plan.add_link_provider(provider)
        end
      end

      def add_consumed_links(instance_group, job)
        @logger.debug("ALL CONSUMED LINKS#{job.consumed_links(instance_group.name)}")
        job.consumed_links(instance_group.name).each do |consumed_link|
          @logger.debug("QQQQQQQQ #{consumed_link.inspect} | #{job.name}")
          consumer = Bosh::Director::Models::LinkConsumer.find(
            deployment: @deployment_plan.model,
            instance_group: instance_group.name,
            owner_object_name: job.name)

          if consumer.nil?
            consumer = Bosh::Director::Models::LinkConsumer.new(
              deployment: @deployment_plan.model,
              instance_group: instance_group.name,
              owner_object_name: job.name,
              owner_object_type: 'Job',
            )
          end
          consumer.save
          @deployment_plan.add_link_consumer(consumer)

          link_path = instance_group.link_path(job.name, consumed_link.original_name)
          next if link_path.nil?
          next if link_path.disk? # TODO: Deal with disk links.

          provider = nil
          if link_path.manual_spec.nil?
            provider_deployment = Models::Deployment[name: link_path.deployment]
            provider = Bosh::Director::Models::LinkProvider.find(deployment: provider_deployment, instance_group: link_path.job, owner_object_name: link_path.template, name: consumed_link.name)

            if provider.nil? # implicit links
              # When calculating link_path it will have failed if the link is ambiguous.
              provider = Bosh::Director::Models::LinkProvider.find(deployment: @deployment_plan.model, link_provider_definition_type: consumed_link.type)
            end
            link_content = provider[:content]
          else
            link_content = link_path.manual_spec.to_json
          end

          Bosh::Director::Models::Link.create(
            {
              name: consumed_link.original_name,
              link_consumer: consumer,
              link_provider: provider,
              link_content: link_content,
              created_at: Time.now
            }
          )
        end
      end
    end
  end
end
