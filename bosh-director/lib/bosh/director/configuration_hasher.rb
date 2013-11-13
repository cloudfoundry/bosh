require 'bosh/director/job_template_loader'

module Bosh::Director
  class ConfigurationHasher
    # @param [DeploymentPlan::Job]
    def initialize(job)
      @job = job
      @logger = Config.logger
      @job_template_loader = JobTemplateLoader.new
    end

    def hash
      job_templates = {}
      sorted_jobs = @job.templates.sort { |x, y| x.name <=> y.name }
      sorted_jobs.each do |job_template|
        job_templates[job_template.name] = @job_template_loader.process(job_template)
      end

      @job.instances.each do |instance|
        instance_digest = Digest::SHA1.new
        template_digests = {}
        sorted_jobs.each do |job_template|
          templates = job_templates[job_template.name].templates
          monit_template = job_templates[job_template.name].monit_template

          binding_helper = Bosh::Common::TemplateEvaluationContext.new(instance.spec)

          bound_templates = bind_template(monit_template, binding_helper, instance.index)

          templates.keys.sort.each do |template_name|
            template = templates[template_name]
            bound_templates << bind_template(template, binding_helper, instance.index)
            template_digest = Digest::SHA1.new
            template_digest << bound_templates
            instance_digest << bound_templates
            template_digests[job_template.name] = template_digest.hexdigest
          end
        end
        instance.configuration_hash = instance_digest.hexdigest
        instance.template_hashes = template_digests
      end
    end

    def bind_template(template, binding_helper, index)
      template.result(binding_helper.get_binding)
    rescue Exception => e
      @logger.debug(e.inspect)
      job_desc = "#{@job.name}/#{index}"
      line_index = e.backtrace.index{ |l| l.include?(template.filename) }
      line = line_index ? e.backtrace[line_index] : '(unknown):(unknown)'
      template_name, line = line.split(':')

      message = "Error filling in template `#{File.basename(template_name)}' " +
                "for `#{job_desc}' (line #{line}: #{e})"

      @logger.debug("#{message}\n#{e.backtrace.join("\n")}")
      raise JobTemplateBindingFailed, "#{message}"
    end
  end
end
