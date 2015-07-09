module Bosh::Director
  module DeploymentPlan
    # tested in link_resolver_spec

    class LinkLookupFactory
      def self.create(required_link, link_path, deployment_plan)
        if link_path.deployment == deployment_plan.name
          PlannerLinkLookup.new(required_link, link_path, deployment_plan)
        else
          deployment = Models::Deployment.find(name: link_path.deployment)
          unless deployment
            raise DeploymentInvalidLink, "Link '#{required_link}' references unknown deployment '#{link_path.deployment}'"
          end

          DeploymentLinkSpecLookup.new(required_link, link_path, deployment.link_spec)
        end
      end
    end

    private

    # Used to find link source from deployment plan
    class PlannerLinkLookup
      def initialize(required_link, link_path, deployment_plan)
        @required_link = required_link
        @link_path = link_path
        @jobs = deployment_plan.jobs
      end

      def find_link_spec
        job = @jobs.find { |j| j.name == @link_path.job }
        return nil unless job

        template = job.templates.find { |t| t.name == @link_path.template }
        return nil unless template

        found = template.provided_links.find { |p| p.name == @link_path.name && p.type == @required_link.type }
        return nil unless found

        Link.new(@link_path.name, job).spec
      end
    end

    # Used to find link source from link spec in deployment model (saved in DB)
    class DeploymentLinkSpecLookup
      def initialize(required_link, link_path, deployment_link_spec)
        @required_link = required_link
        @link_path = link_path
        @deployment_link_spec = deployment_link_spec
      end

      def find_link_spec
        job = @deployment_link_spec[@link_path.job]
        return nil unless job

        template = job[@link_path.template]
        return nil unless template

        link_path = template.fetch(@link_path.name, {})[@required_link.type]
        return nil unless link_path

        link_path
      end
    end
  end
end
