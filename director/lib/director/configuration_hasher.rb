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
    end

    def extract_template
      @template_dir = Dir.mktmpdir("template_dir")
      temp_path = File.join(Dir::tmpdir, "template-#{UUIDTools::UUID.random_create}")
      begin
        File.open(temp_path, "w") do |file|
          Config.blobstore.get(@job.template.blobstore_id, file)
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
        config_templates = []

        if manifest["templates"]
          manifest["templates"].each_key do |config_file|
            config_templates << ERB.new(File.new(File.join(@template_dir, "templates", config_file)).read)
          end
        end

        @job.instances.each do |instance|
          binding_helper = BindingHelper.new(@job.name, instance.index, @job.properties.to_openstruct,
                                             instance.spec.to_openstruct)
          digest = Digest::SHA1.new
          digest << monit_template.result(binding_helper.get_binding)
          config_templates.each do |template|
            digest << template.result(binding_helper.get_binding)
          end
          instance.configuration_hash = digest.hexdigest
        end
      ensure
        FileUtils.rm_rf(@template_dir) if @template_dir
      end
    end

  end
end
