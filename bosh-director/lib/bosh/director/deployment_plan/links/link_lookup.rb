module Bosh::Director
  module DeploymentPlan
    # tested in link_resolver_spec

    class LinkLookupFactory
      def self.create(consumed_link, link_path, deployment_plan, link_network, consumes_job, consumes_template)
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
        @jobs = deployment_plan.jobs
        @link_network = link_network
      end

      def find_link_spec
        job = @jobs.find { |j| j.name == @link_path.job }
        return nil unless job

        template = job.templates.find { |t| t.name == @link_path.template }
        return nil unless template

        found = template.provided_links(job.name).find { |p| p.name == @link_path.name && p.type == @consumed_link.type }
        return nil unless found

        Link.new(@link_path.name, job, template, @link_network).spec
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