module Bosh::Director
  module DeploymentPlan
    class LinksResolver
      def initialize(deployment_plan, logger)
        @deployment_plan = deployment_plan
        @logger = logger
      end

      def resolve(job)
        @logger.debug("Resolving links for job '#{job.name}'")

        job.templates.each do |template|
          resolve_required_links(job, template)
          save_provided_links(job, template)
        end
      end

      private

      def resolve_required_links(job, template)
        template.required_links.each do |required_link|
          link_name = required_link.name

          @logger.debug("Looking for link '#{link_name}' for job '#{job.name}'")

          link_path = job.link_path(template.name, link_name)
          unless link_path
            raise JobMissingLink,
              "Link path was not provided for required link '#{link_name}' in job '#{job.name}'"
          end

          if link_path.name != required_link.name
            raise DeploymentInvalidLink, "Link '#{required_link}' must reference link with the same name"
          end

          link_lookup = LinkLookupFactory.create(required_link, link_path, @deployment_plan)
          link_spec = link_lookup.find_link_spec

          unless link_spec
            raise DeploymentInvalidLink, "Link '#{link_name}' can not be found by path '#{link_path}'"
          end

          job.add_resolved_link(link_name, link_spec)
        end
      end

      def save_provided_links(job, template)
        template.provided_links.each do |provided_link|
          link_spec = Link.new(provided_link.name, job).spec

          @logger.debug("Saving link spec for job '#{job.name}', template: '#{template.name}', link: '#{provided_link}', spec: '#{link_spec}'")

          @deployment_plan.link_spec[job.name][template.name][provided_link.name][provided_link.type] = link_spec
        end
      end
    end
  end
end
