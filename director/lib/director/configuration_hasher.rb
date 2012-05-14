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
      temp_path = File.join(Dir::tmpdir, "template-#{UUIDTools::UUID.random_create}")
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
        monit_template = ERB.new(File.new(File.join(@template_dir, "monit")).read)
        monit_template.filename = File.join(@job.template.name, "monit")
        config_templates = {}

        if manifest["templates"]
          manifest["templates"].each_key do |config_file|
            config_templates[config_file] = ERB.new(File.new(File.join(@template_dir, "templates", config_file)).read)
          end
        end

        @job.instances.each do |instance|
          binding_helper = BindingHelper.new(@job.name, instance.index, @job.properties.to_openstruct,
                                             instance.spec.to_openstruct)
          digest = Digest::SHA1.new
          digest << bind_template(monit_template, binding_helper, "monit", instance.index)
          template_names = config_templates.keys.sort
          template_names.each do |template_name|
            template = config_templates[template_name]
            template.filename = File.join(@job.template.name, template_name)
            digest << bind_template(template, binding_helper, template_name, instance.index)
          end
          instance.configuration_hash = digest.hexdigest
        end
      ensure
        FileUtils.rm_rf(@template_dir) if @template_dir
      end
    end

    def bind_template(template, binding_helper, template_name, index)
      template.result(binding_helper.get_binding)
    rescue Exception => e
      line = e.backtrace.first
      line = line[0..line.rindex(":") - 1]
      @logger.debug("Error filling in template #{line} for #{@job.name}/#{index}: '#{e}', #{e.backtrace.pretty_inspect}")
      raise "Error filling in template #{line} for #{@job.name}/#{index}: '#{e}'"
    end

  end
end
