# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class ConfigurationHasher
    # @param [DeploymentPlan::Job]
    def initialize(job)
      @job = job
      @logger = Config.logger
    end

    # @param [DeploymentPlan::Template] template Template to extract
    # @return [String] Path to a directory where template has been extracted
    def extract_template(template)
      temp_path = template.download_blob
      template_dir = Dir.mktmpdir("template_dir")

      output = `tar -C #{template_dir} -xzf #{temp_path} 2>&1`
      if $?.exitstatus != 0
        raise JobTemplateUnpackFailed,
              "Cannot unpack `#{template.name}' job template, " +
              "tar returned #{$?.exitstatus}, " +
              "tar output: #{output}"
      end

      template_dir
    ensure
      FileUtils.rm_f(temp_path) if temp_path
    end

    # @param [DeploymentPlan::Template]
    def process_template(job_template)
      template_dir = extract_template(job_template)
      manifest = YAML.load_file(File.join(template_dir, "job.MF"))

      monit_template = erb(File.join(template_dir, "monit"))
      monit_template.filename = File.join(job_template.name, "monit")

      templates = {}

      if manifest["templates"]
        manifest["templates"].each_key do |template_name|
          template = erb(File.join(template_dir, "templates", template_name))
          templates[template_name] = template
        end
      end

      @cached_templates[job_template.name] = {
        "templates" => templates,
        "monit_template" => monit_template
      }
    ensure
      FileUtils.rm_rf(template_dir) if template_dir
    end

    def hash
      @cached_templates = {}
      sorted_jobs = @job.templates.sort { |x, y| x.name <=> y.name }
      sorted_jobs.each do |job_template|
        process_template(job_template)
      end
      @job.instances.each do |instance|
        instance_digest = Digest::SHA1.new
        template_digests = {}
        sorted_jobs.each do |job_template|
          templates = @cached_templates[job_template.name]["templates"]
          monit_template =
              @cached_templates[job_template.name]["monit_template"]

          binding_helper = Bosh::Common::TemplateEvaluationContext.new(
            instance.spec)

          bound_templates = bind_template(monit_template, binding_helper,
                                          instance.index)

          templates.keys.sort.each do |template_name|
            template = templates[template_name]
            template.filename = File.join(job_template.name, template_name)
            bound_templates << bind_template(template, binding_helper,
                                             instance.index)
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
      job_desc = "#{@job.name}/#{index}"
      line = e.backtrace.first
      template_name, line = line[0..line.rindex(":") - 1].split(":")

      message = "Error filling in template `#{File.basename(template_name)}' " +
                "for `#{job_desc}' (line #{line}: #{e})"

      @logger.debug("#{message}\n#{e.backtrace.join("\n")}")
      raise JobTemplateBindingFailed, "#{message}"
    end

    private

    def erb(path)
      ERB.new(File.read(path))
    end

  end
end
