module Bosh::Director
  module DeploymentPlan
    # tested in link_resolver_spec

    class LinkLookupFactory
      def self.create(consumed_link, link_path, deployment_plan, link_network)
        if link_path.deployment == deployment_plan.name
          PlannerLinkLookup.new(consumed_link, link_path, deployment_plan, link_network)
        else
          deployment = Models::Deployment.find(name: link_path.deployment)
          unless deployment
            raise DeploymentInvalidLink, "Link '#{consumed_link}' references unknown deployment '#{link_path.deployment}'"
          end
          DeploymentLinkSpecLookup.new(consumed_link, link_path, deployment.link_spec, link_network)
        end
      end
    end

    private

    # Used to find link source from deployment plan
    class PlannerLinkLookup
      def initialize(consumed_link, link_path, deployment_plan, link_network)
        @consumed_link = consumed_link
        @link_path = link_path
        @instance_groups = deployment_plan.instance_groups
        @link_network = link_network
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

          Link.new(@link_path.deployment, @link_path.name, instance_group, job, @link_network).spec
        end
      end
    end

    # Used to find link source from link spec in deployment model (saved in DB)
    class DeploymentLinkSpecLookup
      def initialize(consumed_link, link_path, deployment_link_spec, link_network)
        @consumed_link = consumed_link
        @link_path = link_path
        @deployment_link_spec = deployment_link_spec
        @link_network = link_network
      end

      def find_link_spec
        job = @deployment_link_spec[@link_path.job]
        return nil unless job

        template = job[@link_path.template]
        return nil unless template

        link_spec = template.fetch(@link_path.name, {})[@consumed_link.type]
        return nil unless link_spec

        if @link_network
          link_spec['instances'].each do |instance|
            instance['address'] = instance['addresses'][@link_network]
          end
        end

        link_spec
      end
    end
  end
end
