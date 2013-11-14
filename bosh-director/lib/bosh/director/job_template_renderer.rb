module Bosh::Director
  class JobTemplateRenderer

    attr_reader :monit_template, :templates

    def initialize(monit_template, templates)
      @monit_template = monit_template
      @templates = templates
      @logger = Config.logger
    end

    def render(job_name, instance)
      template_context = Bosh::Common::TemplateEvaluationContext.new(instance.spec)

      monit = render_erb(job_name, monit_template, template_context, instance.index)
      rendered_templates = {}
      templates.keys.sort.each do |name|
        rendered_templates[name] = render_erb(job_name, templates[name], template_context, instance.index)
      end
      return RenderedJobTemplate.new(monit, rendered_templates)
    end

    private

    def render_erb(job_name, template, template_context, index)
      template.result(template_context.get_binding)
    rescue Exception => e
      @logger.debug(e.inspect)
      job_desc = "#{job_name}/#{index}"
      line_index = e.backtrace.index{ |l| l.include?(template.filename) }
      line = line_index ? e.backtrace[line_index] : '(unknown):(unknown)'
      template_name, line = line.split(':')

      message = "Error filling in template `#{File.basename(template_name)}' " +
        "for `#{job_desc}' (line #{line}: #{e})"

      @logger.debug("#{message}\n#{e.backtrace.join("\n")}")
      raise JobTemplateBindingFailed, "#{message}"
    end
  end

  RenderedJobTemplate = Struct.new(:monit, :templates)
end