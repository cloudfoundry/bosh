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
          unless template.required_links_provided?
            raise JobMissingLink,
              "Job '#{job.name}' requires links: #{template.required_links.to_a} but only has following links: #{template.links.keys.to_a}"
          end

          @logger.debug("Received required links #{template.required_links.to_a} for template '#{template.name}'")

          template.links.each do |link_name, link_path|
            link_spec = LinkSpec.parse(@deployment_plan.name, link_path, @logger)

            @logger.debug("Looking for link '#{link_name}' for job '#{job.name}'")
            link_source = find_link_source(link_spec)

            if link_source
              @logger.debug("Link '#{link_name}' for job '#{job.name}' was provided by '#{link_source.name}'")

              link = Link.new(link_name, link_source)
              job.add_link(link)
            end
          end
        end
      end

      def find_link_source(link)
        link_source_job = @deployment_plan.jobs.find { |j| j.name == link.job }
        unless link_source_job
          raise DeploymentInvalidLink, "Link '#{link.name}' references non-existent job '#{link.job}'"
        end

        link_source_template = link_source_job.templates.find { |t| t.name == link.template }
        unless link_source_template
          raise DeploymentInvalidLink, "Link '#{link.name}' references non-existent template '#{link.template}' in job '#{link.job}'"
        end

        provided_link = link_source_template.provided_links.find { |p| p == link.name }
        unless provided_link
          raise DeploymentInvalidLink, "Link '#{link.name}' is not provided by template '#{link.template}' in job '#{link.job}'"
        end

        link_source_job
      end

      private

      class LinkSpec < Struct.new(:deployment, :job, :template, :name)
        def self.parse(current_deployment_name, path, logger)
          parts = path.split('.')

          if parts.size == 3
            logger.debug("Link '#{path}' does not specify deployment, using current deployment")
            parts.unshift(current_deployment_name)
          end

          if parts.size != 4
            logger.error("Invalid link format: #{path}")
            raise DeploymentInvalidLink, "Link '#{path}' is in invalid format"
          end

          new(*parts)
        end
      end
    end
  end
end
