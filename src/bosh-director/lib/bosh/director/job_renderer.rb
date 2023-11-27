require 'bosh/director/core/templates/job_template_loader'
require 'bosh/director/core/templates/job_instance_renderer'
require 'bosh/director/core/templates/template_blob_cache'

module Bosh::Director
  class JobRenderer

    # Render the related job templates for each instance plan passed as
    # argument in the 'instance_plans' array.
    #
    # @param [Logging::Logger] logger A logger where to log activity
    # @param [Array<InstancePlan>] instance_plans A list of instance plans
    # @param [TemplateBlobCache] cache A cache through which job blobs are to
    #                                  be fetched
    # @param [DnsEncoder] dns_encoder A DNS encoder for generating Bosh DNS
    #                                 queries out of context and criteria
    # @param [Array<LinkProviderIntent>] link_provider_intents Relevant
    #                                                          context-dependant
    #                                                          link provider
    #                                                          intents
    def self.render_job_instances_with_cache(logger, instance_plans, cache, dns_encoder, link_provider_intents)
      job_template_loader = Core::Templates::JobTemplateLoader.new(
        logger,
        cache,
        link_provider_intents,
        dns_encoder,
      )

      instance_plans.each do |instance_plan|
        render_job_instance(instance_plan, job_template_loader, logger)
      end
    end

    # For one instance plan, create a 'JobInstanceRenderer' object that will
    # lazily load the ERB templates for all desired jobs on the instance, then
    # render these templates with the bindings populated by the
    # 'spec' properties of the instance plan.
    #
    # @param [DeploymentPlan::InstancePlan] instance_plan An instance plan
    # @param [JobTemplateLoader] loader The object that will load the ERB
    #                                   templates
    # @param [Logging::Logger] logger A logger where to log activity
    def self.render_job_instance(instance_plan, loader, logger)
      instance = instance_plan.instance

      if instance_plan.templates.empty?
        logger.debug("Skipping rendering templates for '#{instance}', no templates")
        return
      end

      logger.debug("Rendering templates for instance #{instance}")

      instance_renderer = Core::Templates::JobInstanceRenderer.new(instance_plan.templates, loader)
      rendered_job_instance = instance_renderer.render(get_templates_spec(instance_plan))

      instance_plan.rendered_templates = rendered_job_instance

      instance.configuration_hash = rendered_job_instance.configuration_hash
      instance.template_hashes    = rendered_job_instance.template_hashes
    end

    def self.get_templates_spec(instance_plan)
      instance_plan.spec.as_template_spec
    rescue StandardError => e
      header = "- Unable to render jobs for instance group '#{instance_plan.instance.instance_group_name}'. Errors are:"
      message = FormatterHelper.new.prepend_header_and_indent_body(
        header,
        e.message.strip,
        indent_by: 2,
      )
      raise message
    end
  end
end
