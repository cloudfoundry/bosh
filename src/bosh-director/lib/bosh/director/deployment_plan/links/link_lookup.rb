module Bosh::Director
  module DeploymentPlan
    # tested in link_resolver_spec

    class LinkLookupFactory
      def self.create(consumed_link, link_path, deployment_plan, link_network_options)
        if link_path.deployment == deployment_plan.name
          PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network_options)
        else
          provider_deployment = Models::Deployment.find(name: link_path.deployment)
          unless provider_deployment
            raise DeploymentInvalidLink, "Link '#{consumed_link}' references unknown deployment '#{link_path.deployment}'"
          end

          link_providers = Models::LinkProvider.where(deployment_id: provider_deployment.id).all
          DeploymentLinkProviderLookup.new(consumed_link, link_path, link_providers, link_network_options)
        end
      end
    end

    class BaseLinkLookup
      include IpUtil

      def initialize(link_network_options)
        @preferred_network_name = link_network_options.fetch(:preferred_network_name, nil)
        @global_use_dns_entry = link_network_options.fetch(:global_use_dns_entry)
        @link_use_ip_address = link_network_options.fetch(:link_use_ip_address, nil)

        @logger = Config.logger
        @event_log = Config.event_log
      end

      private

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

    # Used to find link source from deployment plan
    class PlannerLinkLookup < BaseLinkLookup
      def initialize(consumed_link, link_path, deployment_plan, link_network_options)
        super(link_network_options)
        @consumed_link = consumed_link
        @link_path = link_path
        @deployment_plan = deployment_plan
      end

      def find_link_provider
        instance_group = @deployment_plan.instance_groups.find { |instance_group| instance_group.name == @link_path.job }

        return nil unless instance_group

        if @link_path.disk?
          return DiskLink.new(@link_path.deployment, @link_path.name).spec
        else
          job = instance_group.jobs.find { |job| job.name == @link_path.template }
          return nil unless job

          found = job.provided_links(instance_group.name).find { |p| p.name == @link_path.name && p.type == @consumed_link.type }
          return nil unless found

          link_spec = Link.new(@link_path.deployment, @link_path.name, instance_group, job).spec

          return update_addresses!(link_spec)
        end
      end

      private

      def update_addresses!(link_spec)
        if @link_use_ip_address.nil?
          use_dns_address = @global_use_dns_entry
        else
          use_dns_address = !@link_use_ip_address
        end

        network_name = @preferred_network_name || link_spec['default_network']
        link_spec['default_network'] = network_name

        link_spec['instances'].each do |instance|
          if use_dns_address
            addresses = instance['dns_addresses']
          else
            addresses = instance['addresses']
          end

          raise Bosh::Director::LinkLookupError, "Provider link does not have network: '#{network_name}'" unless addresses.key?(network_name)

          instance['address'] = addresses[network_name]
          log_warning_if_applicable(instance['address'], use_dns_address, instance['name'], instance['id'])
        end

        link_spec['instances'].each do |instance|
          instance.delete('addresses')
          instance.delete('dns_addresses')
        end

        link_spec
      end
    end

    # Used to find link source from link spec in deployment model (saved in DB)
    class DeploymentLinkProviderLookup < BaseLinkLookup
      def initialize(consumed_link, link_path, deployment_link_provider, link_network_options)
        super(link_network_options)
        @consumed_link = consumed_link
        @link_path = link_path
        @deployment_link_provider = deployment_link_provider
      end

      def find_link_provider
        return nil if @deployment_link_provider.empty?

        job = @deployment_link_provider.select{|lp|
          lp[:instance_group] == @link_path.job &&
          lp[:owner_object_name] == @link_path.template &&
          lp[:name] == @link_path.name}
        return nil if job.empty?

        template = job.select{|j| j[:link_provider_definition_type] == @consumed_link.type }
        return nil if template.empty?

        update_addresses!(JSON.parse(template.first[:content]))
      end

      private

      def update_addresses!(link_spec)
        link_spec_copy = Bosh::Common::DeepCopy.copy(link_spec)
        if !link_spec_copy.has_key?('default_network')
          if !@link_use_ip_address.nil?
            raise Bosh::Director::LinkLookupError, 'Unable to retrieve default network from provider. Please redeploy provider deployment'
          end

          if @preferred_network_name
            link_spec_copy['instances'].each do |instance|
              desired_addresses = instance['addresses']
              raise Bosh::Director::LinkLookupError, "Provider link does not have network: '#{@preferred_network_name}'" unless desired_addresses.key?(@preferred_network_name)
              instance['address'] = desired_addresses[@preferred_network_name]
              log_warning_if_applicable(instance['address'], @global_use_dns_entry, instance['name'], instance['id'])
            end
          end
        else
          if @link_use_ip_address.nil?
            use_dns_entries = @global_use_dns_entry
          else
            use_dns_entries = !@link_use_ip_address
          end

          network_name = @preferred_network_name || link_spec_copy['default_network']
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
    end
  end
end
