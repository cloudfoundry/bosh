module Bosh::Director
  class RenderedJobInstanceHasher
    def initialize(job_templates)
      @job_templates = job_templates
    end

    def configuration_hash
      instance_digest, _ = render_digest
      instance_digest
    end

    def template_hashes
      _, template_digests = render_digest
      template_digests
    end

    private
    attr_reader :job_templates

    def render_digest
      instance_digest = Digest::SHA1.new
      template_digests = {}
      job_templates.sort { |x, y| x.name <=> y.name }.each do |rendered_job_template|
        bound_templates = ''
        bound_templates << rendered_job_template.monit

        rendered_job_template.templates.keys.sort.each do |src_name|
          bound_templates << rendered_job_template.templates[src_name]
          instance_digest << bound_templates
        end

        template_digest = Digest::SHA1.new
        template_digest << bound_templates
        template_digests[rendered_job_template.name] = template_digest.hexdigest
      end
      return instance_digest.hexdigest, template_digests
    end
  end
end
