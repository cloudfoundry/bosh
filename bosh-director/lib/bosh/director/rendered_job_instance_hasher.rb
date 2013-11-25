module Bosh::Director
  class RenderedJobInstanceHasher
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

    private
    attr_reader :job_templates
  end
end
