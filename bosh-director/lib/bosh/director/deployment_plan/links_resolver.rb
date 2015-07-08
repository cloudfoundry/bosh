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
          template.required_links.each do |required_link|
            link_name = required_link.name

            @logger.debug("Looking for link '#{link_name}' for job '#{job.name}'")

            link_path = job.link_path(template.name, link_name)
            unless link_path
              raise JobMissingLink,
                "Link path was not provided for required link '#{link_name}' in job '#{job.name}'"
            end

            link_spec = DeploymentLinkSpec.parse(@deployment_plan.name, link_path, @logger)
            if link_spec.name != required_link.name
              raise DeploymentInvalidLink, "Link '#{required_link}' must reference link with the same name"
            end

            link_source = find_link_source(required_link, link_spec)
            unless link_source
              raise DeploymentInvalidLink, "Link '#{link_name}' can not be found in deployment"
            end

            @logger.debug("Link '#{link_name}' for job '#{job.name}' was provided by '#{link_source.name}'")
            link = Link.new(link_name, link_source)
            job.add_resolved_link(link)
          end
        end
      end

      def find_link_source(required_link, link_spec)
        link_source_job = @deployment_plan.jobs.find { |j| j.name == link_spec.job }
        unless link_source_job
          raise DeploymentInvalidLink, "Link '#{required_link}' references unknown job '#{link_spec.job}'"
        end

        link_source_template = link_source_job.templates.find { |t| t.name == link_spec.template }
        unless link_source_template
          raise DeploymentInvalidLink, "Link '#{required_link}' references unknown template '#{link_spec.template}' in job '#{link_spec.job}'"
        end

        provided_link = link_source_template.provided_links.find { |p| p.name == link_spec.name && p.type == required_link.type }
        unless provided_link
          raise DeploymentInvalidLink, "Link '#{required_link}' is not provided by template '#{link_spec.template}' in job '#{link_spec.job}'"
        end

        link_source_job
      end

      private

      class DeploymentLinkSpec < Struct.new(:deployment, :job, :template, :name)
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
