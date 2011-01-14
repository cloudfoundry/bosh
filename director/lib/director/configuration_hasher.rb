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
      @template = Config.blobstore.get(job.template.blobstore_id)
    end

    def extract_template
      @template_dir = Dir.mktmpdir("template_dir")
      temp_file = Tempfile.new("template")
      begin
        File.open(temp_file.path, "w") do |f|
          f.write(@template)
        end
        `tar -C #{@template_dir} -xzf #{temp_file.path}`
      ensure
        FileUtils.rm_f(temp_file.path) if temp_file
      end
    end

    def hash
      begin
        extract_template
        manifest = YAML.load_file(File.join(@template_dir, "job.MF"))
        monit_template = ERB.new(File.new(File.join(@template_dir, "monit")).read)
        config_templates = []

        if manifest["configuration"]
          manifest["configuration"].each_key do |config_file|
            config_templates << ERB.new(File.new(File.join(@template_dir, "config", config_file)).read)
          end
        end

        digest = Digest::SHA1.new
        digest << @template

        @job.instances.each do |instance|
          binding_helper = BindingHelper.new(@job.name, instance.index, @job.properties.to_openstruct,
                                             instance.spec.to_openstruct)
          instance_digest = digest.dup
          instance_digest << monit_template.result(binding_helper.get_binding)
          config_templates.each do |template|
            instance_digest << template.result(binding_helper.get_binding)
          end
          instance.configuration_hash = instance_digest.hexdigest
        end
      ensure
        FileUtils.rm_rf(@template_dir) if @template_dir
      end
    end

  end
end
