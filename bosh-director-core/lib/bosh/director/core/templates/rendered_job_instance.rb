require 'bosh/director/core/templates'
require 'bosh/director/core/templates/rendered_templates_archive'
require 'bosh/director/core/templates/compressed_rendered_job_templates'
require 'digest/sha1'
require 'tempfile'

module Bosh::Director::Core::Templates
  class RenderedJobInstance
    def initialize(job_templates)
      @job_templates = job_templates
    end

    def configuration_hash
      instance_digest = Digest::SHA1.new
      job_templates.sort { |x, y| x.name <=> y.name }.each do |rendered_job_template|
        bound_templates = ''
        bound_templates << rendered_job_template.monit

        rendered_job_template.templates.sort { |x, y| x.src_name <=> y.src_name }.each do |template_file|
          bound_templates << template_file.contents
          instance_digest << bound_templates
        end
      end

      instance_digest.hexdigest
    end

    def template_hashes
      job_templates.reduce({}) do |h, rendered_job_template|
        h.merge(rendered_job_template.name => rendered_job_template.template_hash)
      end
    end

    def persist(blobstore)
      file = Tempfile.new('compressed-rendered-job-templates')

      compressed_archive = CompressedRenderedJobTemplates.new(file.path)
      compressed_archive.write(job_templates)

      blobstore_id = blobstore.create(compressed_archive.contents)
      RenderedTemplatesArchive.new(blobstore_id, compressed_archive.sha1)
    ensure
      file.close!
    end

    private

    attr_reader :job_templates
  end
end
