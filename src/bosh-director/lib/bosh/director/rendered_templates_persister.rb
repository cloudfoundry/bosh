require 'securerandom'
require 'base64'

module Bosh::Director
  class RenderedTemplatesPersister

    def initialize(blobstore_client, logger)
      @blobstore_client = blobstore_client
      @enable_nats_delivery = Config.enable_nats_delivered_templates
      @logger = logger
    end

    def persist(instance_plan)
      if @enable_nats_delivery
        begin
          send_templates_to_agent(instance_plan)
        rescue Bosh::Director::AgentUnsupportedAction, Bosh::Director::AgentUploadBlobUnableToOpenFile
          persist_on_blobstore(instance_plan)
        end
      else
        persist_on_blobstore(instance_plan)
      end
    end

    private

    def persist_on_blobstore(instance_plan)
      instance = instance_plan.instance

      unless instance_plan.rendered_templates
        @logger.debug("Skipping persisting templates for '#{instance}', no templates")
        return
      end

      rendered_templates_archive_model = instance.model.latest_rendered_templates_archive

      if rendered_templates_archive_model && rendered_templates_archive_model.content_sha1 == instance.configuration_hash
        if !@blobstore_client.exists?(rendered_templates_archive_model.blobstore_id)

          compressed_templates_archive = instance_plan.rendered_templates.persist_on_blobstore(@blobstore_client)

          blobstore_id = compressed_templates_archive.blobstore_id
          archive_sha1 = compressed_templates_archive.sha1

          rendered_templates_archive_model.update({
            :blobstore_id => blobstore_id,
            :sha1 => archive_sha1
          })
        else
          blobstore_id = rendered_templates_archive_model.blobstore_id
          archive_sha1 = rendered_templates_archive_model.sha1
        end
      else
        compressed_templates_archive = instance_plan.rendered_templates.persist_on_blobstore(@blobstore_client)

        blobstore_id = compressed_templates_archive.blobstore_id
        archive_sha1 = compressed_templates_archive.sha1

        instance.model.add_rendered_templates_archive(
          blobstore_id: blobstore_id,
          sha1: archive_sha1,
          content_sha1: instance.configuration_hash,
          created_at: Time.now,
        )
      end

      rendered_templates_archive = Core::Templates::RenderedTemplatesArchive.new(
        blobstore_id,
        archive_sha1,
      )
      instance.rendered_templates_archive = rendered_templates_archive
    end

    def send_templates_to_agent(instance_plan)
      instance = instance_plan.instance

      unless instance_plan.rendered_templates
        @logger.debug("Skipping persisting templates for '#{instance}', no templates")
        return
      end

      rendered_templates_archive = instance_plan.rendered_templates.persist_through_agent(instance.agent_client)

      instance.model.add_rendered_templates_archive(rendered_templates_archive.spec.merge({
        content_sha1: instance.configuration_hash,
        created_at: Time.now,
      }))
      instance.rendered_templates_archive = rendered_templates_archive
    end
  end
end
