module Bosh::Director
  class RenderedJobInstanceHasher
    def initialize(job_templates)
      @job_templates = job_templates
    end

    def configuration_hash
      instance_digest = Digest::SHA1.new
      sorted_jobs.each do |rendered_job_template|
        bound_templates = ''
        bound_templates << rendered_job_template.monit

        rendered_job_template.templates.keys.sort.each do |src_name|
          bound_templates << rendered_job_template.templates[src_name]
          instance_digest << bound_templates
        end
      end

      instance_digest.hexdigest
    end

    def template_hashes
      sorted_jobs.reduce({}) do |h, rendered_job_template|
        h.merge(rendered_job_template.name => template_hash(rendered_job_template))
      end
    end

    private
    attr_reader :job_templates

    def sorted_jobs
      job_templates.sort { |x, y| x.name <=> y.name }
    end

    def template_hash(job_template)
      template_digest = Digest::SHA1.new
      template_digest << job_template.monit
      job_template.templates.keys.sort.each do |src_name|
        template_digest << job_template.templates[src_name]
      end
      template_digest.hexdigest
    end
  end
end
