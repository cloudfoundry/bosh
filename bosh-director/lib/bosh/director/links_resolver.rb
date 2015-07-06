module Bosh::Director
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

        template.links.each do |_, link_path|
          link = Link.parse(link_path, @logger)

          find_link_source(link)
        end
      end
    end

    def find_link_source(link)
      link_source_job = @deployment_plan.jobs.find { |j| j.name == link.job }
      unless link_source_job
        raise DeploymentInvalidLink, "Link '#{link.name}' references non-existent job '#{link.job}'"
      end

      link_source_template = link_source_job.templates.find {|t| t.name == link.template}
      unless link_source_template
        raise DeploymentInvalidLink, "Link '#{link.name}' references non-existent template '#{link.template}' in job '#{link.job}'"
      end

      provided_link = link_source_template.provided_links.find { |p| p == link.name }
      unless provided_link
        raise DeploymentInvalidLink, "Link '#{link.name}' is not provided by template '#{link.template}' in job '#{link.job}'"
      end
    end

    private

    class Link < Struct.new(:deployment, :job, :template, :name, :logger)
      def self.parse(path, logger)
        parts = path.split('.')
        if parts.size != 4
          logger.error("Invalid link format: #{path}")
          raise DeploymentInvalidLink, "Link '#{path}' is in invalid format"
        end

        new(*parts, logger)
      end
    end
  end
end
