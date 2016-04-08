module Bosh::Director
  module DeploymentPlan
    class LinksResolver
      def initialize(deployment_plan, logger)
        @deployment_plan = deployment_plan
        @logger = logger
      end

      def resolve(job)
        @logger.debug("Resolving links for instance group '#{job.name}'")

        job.templates.each do |template|
          resolve_consumed_links(job, template)
          ensure_all_links_in_consumes_block_are_mentioned_in_spec(job, template)
          save_provided_links(job, template)
        end
      end

      private

      def resolve_consumed_links(job, template)
        template.model_consumed_links.each do |consumed_link|
          link_name = consumed_link.name

          link_path = job.link_path(template.name, link_name)

          if link_path.nil?
            # Only raise an exception when the link_path is nil, and it is not optional
            if !consumed_link.optional
              raise JobMissingLink, "Link path was not provided for required link '#{link_name}' in instance group '#{job.name}'"
            end
          elsif !link_path.manual_spec.nil?
            job.add_resolved_link(link_name, link_path.manual_spec)
          else
            link_network = template.consumes_link_info(job.name, link_name)['network']
            link_lookup = LinkLookupFactory.create(consumed_link, link_path, @deployment_plan, link_network, job.name, template.name)
            link_spec = link_lookup.find_link_spec

            unless link_spec
              raise DeploymentInvalidLink, "Cannot resolve link path '#{link_path}' required for link '#{link_name}' in instance group '#{job.name}' on job '#{template.name}'"
            end

            link_spec['instances'].each do |instance|
              instance.delete('addresses')
            end

            job.add_resolved_link(link_name, link_spec)
          end
        end
      end

      def save_provided_links(job, template)
        template.provided_links(job.name).each do |provided_link|
          if provided_link.shared
            link_spec = Link.new(provided_link.name, job, template).spec
            @logger.debug("Saving link spec for job '#{job.name}', template: '#{template.name}', link: '#{provided_link}', spec: '#{link_spec}'")
            @deployment_plan.link_spec[job.name][template.name][provided_link.name][provided_link.type] = link_spec
          end
        end
      end

      def ensure_all_links_in_consumes_block_are_mentioned_in_spec(job, template)
        return if job.link_paths.empty?
        job.link_paths[template.name].to_a.each do |link_name, _|
          unless template.model_consumed_links.map(&:name).include?(link_name)
            raise Bosh::Director::UnusedProvidedLink,
              "Job '#{template.name}' in instance group '#{job.name}' specifies link '#{link_name}', " +
                "but the release job does not consume it."
          end
        end
      end
    end
  end
end
