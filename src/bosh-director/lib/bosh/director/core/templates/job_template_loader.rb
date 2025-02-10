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

      # Perform these operations in order:
      #
      #  1. Download (or fetch from cache) a single job blob tarball.
      #
      #  2. Extract the job blob tarball in a temporary directory.
      #
      #  3. Access the extracted 'job.MF' manifest from the job blob.
      #
      #  4. Load all ERB templates (including the 'monit' file and all other
      #     declared files within the 'templates' subdir) and create one
      #     'SourceErb' object for each of these.
      #
      #  5. Create and return a 'JobTemplateRenderer' object, populated with
      #     all created 'SourceErb' objects.
      #
      # @param [DeploymentPlan::Job] instance_job The job whose templates
      #                                           should be rendered
      # @return [JobTemplateRenderer] Object that can render the templates
      def process(instance_job)
        template_dir = extract_template(instance_job)

        monit_erb_file = File.read(File.join(template_dir, 'monit'))
        monit_source_erb = SourceErb.new('monit', 'monit', monit_erb_file, instance_job.name)

        if File.exist?(File.join(template_dir, 'properties_schema.json'))
          properties_schema = JSON.load_file(File.join(template_dir, 'properties_schema.json'))
        else
          properties_schema = nil
        end

        source_erbs = []

        instance_job.model.spec.fetch('templates', {}).each_pair do |src_filepath, dest_filepath|
          erb_contents = File.read(File.join(template_dir, 'templates', src_filepath))
          source_erbs << SourceErb.new(src_filepath, dest_filepath, erb_contents, instance_job.name)
        end

        JobTemplateRenderer.new(instance_job: instance_job,
                                monit_erb: monit_source_erb,
                                source_erbs: source_erbs,
                                properties_schema: properties_schema,
                                logger: @logger,
                                link_provider_intents: @link_provider_intents,
                                dns_encoder: @dns_encoder)
      ensure
        FileUtils.rm_rf(template_dir) if template_dir
      end

      private

      def extract_template(instance_job)
        @logger.debug("Extracting job #{instance_job.name}")
        cached_blob_path = @template_blob_cache.download_blob(instance_job)
        template_dir = Dir.mktmpdir('template_dir')

        output = `tar -C #{template_dir} -xzf #{cached_blob_path} 2>&1`
        if $?.exitstatus != 0
          raise Bosh::Director::JobTemplateUnpackFailed,
            "Cannot unpack '#{instance_job.name}' job blob, " +
              "tar returned #{$?.exitstatus}, " +
              "tar output: #{output}"
        end

        template_dir
      end
    end
  end
end
