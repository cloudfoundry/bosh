module Bosh::Director
  class ConfigurationHasher

    class BindingHelper

      attr_reader :name
      attr_reader :index
      attr_reader :properties

      def initialize(name, index, properties)
        @name = name
        @index = index
        @properties = properties
      end

      def get_binding
        binding
      end

    end

    def initialize(job, template_blobstore_id)
      @job = job
      @template = Config.blobstore.get(template_blobstore_id)
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

        manifest["configuration"].each_key do |config_file|
          config_templates << ERB.new(File.new(File.join(@template_dir, "configuration", config_file)).read)
        end

        digest = Digest::SHA1.new
        digest << @template

        File.open("/tmp/a.tgz", "w") {|f| f.write(@template)}

        @job.instances.each do |instance|
          binding_helper = BindingHelper.new(@job.name, instance.index, @job.properties.to_openstruct)
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