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
          DeploymentLinkSpecLookup.new(consumed_link, link_path, provider_deployment.link_spec, link_network_options)
        end
      end
    end

    private

    class BaseLinkLookup
      def initialize(link_network_options)
        @preferred_network_name = link_network_options.fetch(:preferred_network_name, nil)
        @use_dns_entries = link_network_options.fetch(:use_dns_entry, true)
      end

      def update_addresses!(link_spec)
        network_name = @preferred_network_name || link_spec['default_network']

        unless @use_dns_entries
          raise Bosh::Director::LinkLookupError, 'Unable to retrieve default network from provider. Please redeploy provider deployment' unless network_name
        end

        if network_name
          link_spec['instances'].each do |instance|
            if @use_dns_entries
              addresses = instance['addresses']
            else
              addresses = instance['ip_addresses']
            end

            raise Bosh::Director::LinkLookupError, 'Unable to retrieve network addresses. Please redeploy provider deployment' unless addresses
            raise Bosh::Director::LinkLookupError, "Invalid network name: #{network_name}" unless addresses[network_name]

            instance['address'] = addresses[network_name]
          end
        end
      end
    end

    # Used to find link source from deployment plan
    class PlannerLinkLookup < BaseLinkLookup
      def initialize(consumed_link, link_path, deployment_plan, link_network_options)
        super(link_network_options)
        @consumed_link = consumed_link
        @link_path = link_path
        @instance_groups = deployment_plan.instance_groups
      end

      def find_link_spec
        instance_group = @instance_groups.find { |instance_group| instance_group.name == @link_path.job }
        return nil unless instance_group

        if @link_path.disk?
          DiskLink.new(@link_path.deployment, @link_path.name).spec
        else
          job = instance_group.jobs.find { |job| job.name == @link_path.template }
          return nil unless job

          found = job.provided_links(instance_group.name).find { |p| p.name == @link_path.name && p.type == @consumed_link.type }
          return nil unless found

          link_spec = Link.new(@link_path.deployment, @link_path.name, instance_group, job).spec

          update_addresses!(link_spec)

          link_spec
        end
      end
    end

    # Used to find link source from link spec in deployment model (saved in DB)
    class DeploymentLinkSpecLookup < BaseLinkLookup
      def initialize(consumed_link, link_path, deployment_link_spec, link_network_options)
        super(link_network_options)
        @consumed_link = consumed_link
        @link_path = link_path
        @deployment_link_spec = deployment_link_spec
      end

      def find_link_spec
        job = @deployment_link_spec[@link_path.job]
        return nil unless job

        template = job[@link_path.template]
        return nil unless template

        link_spec = template.fetch(@link_path.name, {})[@consumed_link.type]
        return nil unless link_spec

        update_addresses!(link_spec)

        link_spec
      end
    end
  end
end
