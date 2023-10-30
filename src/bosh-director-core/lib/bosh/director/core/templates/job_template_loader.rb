require 'bosh/director/core/templates'
require 'bosh/director/core/templates/job_template_renderer'
require 'bosh/director/core/templates/source_erb'

module Bosh::Director
  class JobTemplateUnpackFailed < StandardError
  end

  module Core::Templates
    class JobTemplateLoader
      def initialize(logger, template_blob_cache, link_provider_intents, dns_encoder)
        @logger = logger
        @template_blob_cache = template_blob_cache
        @link_provider_intents = link_provider_intents
        @dns_encoder = dns_encoder
      end

      def process(job_template)
        template_dir = extract_template(job_template)
        manifest = Psych.load_file(File.join(template_dir, 'job.MF'), aliases: true)

        monit_erb_file = File.read(File.join(template_dir, 'monit'))
        monit_source_erb = SourceErb.new('monit', 'monit', monit_erb_file, job_template.name)

        source_erbs = []

        template_name = manifest.fetch('name', {})

        manifest.fetch('templates', {}).each_pair do |src_name, dest_name|
          erb_file = File.read(File.join(template_dir, 'templates', src_name))
          source_erbs << SourceErb.new(src_name, dest_name, erb_file, job_template.name)
        end

        JobTemplateRenderer.new(job_template: job_template,
                                template_name: template_name,
                                monit_erb: monit_source_erb,
                                source_erbs: source_erbs,
                                logger: @logger,
                                link_provider_intents: @link_provider_intents,
                                dns_encoder: @dns_encoder)
      ensure
        FileUtils.rm_rf(template_dir) if template_dir
      end

      private

      def extract_template(job_template)
        @logger.debug("Extracting job #{job_template.name}")
        cached_blob_path = @template_blob_cache.download_blob(job_template)
        template_dir = Dir.mktmpdir('template_dir')

        output = `tar -C #{template_dir} -xzf #{cached_blob_path} 2>&1`
        if $?.exitstatus != 0
          raise Bosh::Director::JobTemplateUnpackFailed,
            "Cannot unpack '#{job_template.name}' job template, " +
              "tar returned #{$?.exitstatus}, " +
              "tar output: #{output}"
        end

        template_dir
      end
    end
  end
end
