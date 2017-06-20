module Bosh::Director
  module DeploymentPlan
    class LinksResolver
      def initialize(deployment_plan, logger)
        @deployment_plan = deployment_plan
        @logger = logger
      end

      def resolve(instance_group)
        @logger.debug("Resolving links for instance group '#{instance_group.name}'")

        instance_group.jobs.each do |job|
          resolve_consumed_links(instance_group, job)
          ensure_all_links_in_consumes_block_are_mentioned_in_spec(instance_group, job)
          add_shared_provided_links_to_deployment_plan(instance_group, job)
        end
      end

      private

      def resolve_consumed_links(instance_group, job)
        job.model_consumed_links.each do |consumed_link|
          link_name = consumed_link.name

          link_path = instance_group.link_path(job.name, link_name)

          if link_path.nil?
            # Only raise an exception when the link_path is nil, and it is not optional
            if !consumed_link.optional
              raise JobMissingLink, "Link path was not provided for required link '#{link_name}' in instance group '#{instance_group.name}'"
            end
          elsif !link_path.manual_spec.nil?
            instance_group.add_resolved_link(job.name, link_name, link_path.manual_spec)
          else
            link_network = job.consumes_link_info(instance_group.name, link_name)['network']
            link_lookup = LinkLookupFactory.create(consumed_link, link_path, @deployment_plan, link_network)
            link_spec = link_lookup.find_link_spec

            unless link_spec
              raise DeploymentInvalidLink, "Cannot resolve link path '#{link_path}' required for link '#{link_name}' in instance group '#{instance_group.name}' on job '#{job.name}'"
            end

            link_spec['instances'].each do |instance|
              instance.delete('addresses')
            end

            instance_group.add_resolved_link(job.name, link_name, link_spec)
          end
        end
      end

      def add_shared_provided_links_to_deployment_plan(instance_group, job)
        job.provided_links(instance_group.name).each do |provided_link|
          if provided_link.shared
            link_spec = Link.new(instance_group.deployment_name, provided_link.name, instance_group, job).spec
            @logger.debug("Saving link spec for instance_group '#{instance_group.name}', job: '#{job.name}', link: '#{provided_link}', spec: '#{link_spec}'")
            @deployment_plan.add_deployment_link_spec(instance_group.name, job.name, provided_link.name, provided_link.type, link_spec)
          end
        end
      end

      def ensure_all_links_in_consumes_block_are_mentioned_in_spec(instance_group, job)
        return if instance_group.link_paths.empty?
        instance_group.link_paths[job.name].to_a.each do |link_name, _|
          unless job.model_consumed_links.map(&:name).include?(link_name)
            raise Bosh::Director::UnusedProvidedLink,
              "Job '#{job.name}' in instance group '#{instance_group.name}' specifies link '#{link_name}', " +
                'but the release job does not consume it.'
          end
        end
      end
    end
  end
end
