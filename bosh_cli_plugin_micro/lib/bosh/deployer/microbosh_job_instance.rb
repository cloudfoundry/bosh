require 'bosh/director/core/templates/job_template_loader'
require 'bosh/director/core/templates/job_instance_renderer'
require 'bosh/deployer/job_template'
require 'blobstore_client'

module Bosh::Deployer
  class MicroboshJobInstance

    def initialize(blobstore_ip, mbus, logger)
      @logger = logger

      uri = URI.parse(mbus)
      user, password = uri.userinfo.split(':', 2)
      uri.userinfo = ''
      uri.host = blobstore_ip
      uri.path = '/blobs'
      @blobstore_options = {
        'endpoint' => uri.to_s,
        'user' => user,
        'password' => password,
        'ssl_no_verify' => true,
      }
    end

    def render_templates(spec)
      blobstore = Bosh::Blobstore::DavBlobstoreClient.new(blobstore_options)

      templates = spec['job']['templates'].map do |template|
        JobTemplate.new(template, blobstore)
      end

      job_template_loader =
        Bosh::Director::Core::Templates::JobTemplateLoader.new(logger)
      job_instance_renderer =
        Bosh::Director::Core::Templates::JobInstanceRenderer.new(templates, job_template_loader)

      rendered_job_instance = job_instance_renderer.render(spec)
      rendered_templates_archive = rendered_job_instance.persist(blobstore)

      spec.merge(
        'rendered_templates_archive' => rendered_templates_archive.spec,
        'configuration_hash' => rendered_job_instance.configuration_hash,
      )
    rescue JobTemplate::FetchError
      logger.debug('skipping rendering since the agent appears to be ruby')
      spec
    end

    private

    attr_reader :spec, :blobstore_options, :logger
  end
end
