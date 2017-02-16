require 'bosh/director/core/templates'
require 'bosh/director/core/templates/job_template_renderer'
require 'bosh/director/core/templates/source_erb'

module Bosh::Director::Core::Templates
  class JobTemplateLoader
    def initialize(logger)
      @logger = logger
    end

    def process(job_template)
      template_dir = extract_template(job_template)
      manifest = Psych.load_file(File.join(template_dir, 'job.MF'))

      monit_erb_file = File.read(File.join(template_dir, 'monit'))
      monit_source_erb = SourceErb.new('monit', 'monit', monit_erb_file, job_template.name)

      source_erbs = []

      template_name = manifest.fetch('name', {})

      manifest.fetch('templates', {}).each_pair do |src_name, dest_name|
        erb_file = File.read(File.join(template_dir, 'templates', src_name))
        source_erbs << SourceErb.new(src_name, dest_name, erb_file, job_template.name)
      end

      JobTemplateRenderer.new(job_template.name, template_name, monit_source_erb, source_erbs, @logger)
    ensure
      FileUtils.rm_rf(template_dir) if template_dir
    end

    private

    def extract_template(job_template)
      temp_path = job_template.download_blob
      template_dir = Dir.mktmpdir('template_dir')

      output = `tar -C #{template_dir} -xzf #{temp_path} 2>&1`
      if $?.exitstatus != 0
        raise JobTemplateUnpackFailed,
              "Cannot unpack '#{job_template.name}' job template, " +
                "tar returned #{$?.exitstatus}, " +
                "tar output: #{output}"
      end

      template_dir
    ensure
      FileUtils.rm_f(temp_path) if temp_path
    end
  end
end
