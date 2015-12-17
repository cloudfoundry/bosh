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

          link_lookup = LinkLookupFactory.create(required_link, link_path, @deployment_plan)
          link_spec = link_lookup.find_link_spec

          unless link_spec
            raise DeploymentInvalidLink,
              "Cannot resolve link path '#{link_path}' required for link '#{link_name}' " +
                "in job '#{job.name}' on template '#{template.name}'"
          end

          job.add_resolved_link(link_name, link_spec)
        end

        ensure_provided_links_are_used(job, template)
      end

      def save_provided_links(job, template)
        template.provided_links.each do |provided_link|
          link_spec = Link.new(provided_link.name, job).spec

          @logger.debug("Saving link spec for job '#{job.name}', template: '#{template.name}', " +
              "link: '#{provided_link}', spec: '#{link_spec}'")

          @deployment_plan.link_spec[job.name][template.name][provided_link.name][provided_link.type] = link_spec
        end
      end

      def ensure_provided_links_are_used(job, template)
        return if job.link_paths.empty?
        job.link_paths[template.name].to_a.each do |link_name, _|
          unless template.required_links.map(&:name).include?(link_name)
            raise Bosh::Director::UnusedProvidedLink,
              "Template '#{template.name}' in job '#{job.name}' specifies link '#{link_name}', " +
                "but the release job does not require it."
          end
        end
      end
    end
  end
end
