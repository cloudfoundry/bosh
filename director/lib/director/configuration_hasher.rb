# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class ConfigurationHasher

    class BindingHelper

      attr_reader :name
      attr_reader :index
      attr_reader :properties
      attr_reader :spec

      def initialize(name, index, properties, spec)
        @name = name
        @index = index
        @properties = properties
        @spec = spec
      end

      def get_binding
        binding
      end

    end

    def initialize(job)
      @job = job
      @logger = Config.logger
    end

    def extract_template
      @template_dir = Dir.mktmpdir("template_dir")
      temp_path = File.join(Dir.tmpdir,
                            "template-#{UUIDTools::UUID.random_create}")
      begin
        File.open(temp_path, "w") do |file|
          Config.blobstore.get(@job.template.template.blobstore_id, file)
        end
        `tar -C #{@template_dir} -xzf #{temp_path}`
      ensure
        FileUtils.rm_f(temp_path)
      end
    end

    def hash
      begin
        extract_template
        manifest = YAML.load_file(File.join(@template_dir, "job.MF"))

        monit_template = template_erb("monit")
        monit_template.filename = File.join(@job.template.name, "monit")

        templates = {}

        if manifest["templates"]
          manifest["templates"].each_key do |template_name|
            template = template_erb(File.join("templates", template_name))
            templates[template_name] = template
          end
        end

        @job.instances.each do |instance|
          binding_helper = BindingHelper.new(@job.name, instance.index,
                                             @job.properties.to_openstruct,
                                             instance.spec.to_openstruct)
          digest = Digest::SHA1.new
          digest << bind_template(monit_template,
                                  binding_helper, instance.index)

          templates.keys.sort.each do |template_name|
            template = templates[template_name]
            template.filename = File.join(@job.template.name, template_name)
            digest << bind_template(template, binding_helper, instance.index)
          end
          instance.configuration_hash = digest.hexdigest
        end
      ensure
        FileUtils.rm_rf(@template_dir) if @template_dir
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

    def template_erb(path)
      ERB.new(File.read(File.join(@template_dir, path)))
    end

  end
end
