module Bosh::Director
  module DeploymentPlan
    module Steps
      class RenderInstanceJobTemplatesStep
        def initialize(instance_plan, blob_cache, dns_encoder, link_provider_intents)
          @instance_plan = instance_plan
          @blob_cache = blob_cache
          @dns_encoder = dns_encoder
          @logger = Config.logger
          @link_provider_intents = link_provider_intents
        end

        def perform(_report)
          if @instance_plan.instance.compilation?
            @logger.debug('Skipping job template rendering, as instance is a compilation instance')
          else
            @logger.debug("Re-rendering templates with updated dynamic networks: #{@instance_plan.spec.as_template_spec['networks']}")
            JobRenderer.render_job_instances_with_cache(
              @logger,
              [@instance_plan],
              @blob_cache,
              @dns_encoder,
              @link_provider_intents,
            )
          end
        end
      end
    end
  end
end
