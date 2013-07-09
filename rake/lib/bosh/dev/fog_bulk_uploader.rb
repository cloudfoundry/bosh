require 'fog'
require 'logger'

module Bosh
  module Dev
    class FogBulkUploader
      attr_reader :base_dir

      def self.s3_pipeline
        options = {
            provider: 'AWS',
            aws_access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT'),
            aws_secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT')
        }
        bucket = ENV.fetch('BOSH_CI_PIPELINE_BUCKET', 'bosh-ci-pipeline')

        new(bucket, options)
      end

      def initialize(base_dir, options)
        @options = options.clone
        @base_dir = base_dir
        @logger = Logger.new(STDOUT)
      end

      def fog_storage
        @fog_storage ||= Fog::Storage.new(@options)
      end

      def upload_r(source_dir, dest_dir)
        Dir.chdir(source_dir) do
          Dir['**/*'].each do |file|
            unless File.directory?(file)
              uploaded_file = base_directory.files.create(
                  key: File.join(dest_dir, file),
                  body: File.open(file),
                  public: true
              )
              @logger.info("uploaded #{file} to #{uploaded_file.public_url}")
            end
          end
        end
      end

      def base_directory
        fog_storage.directories.get(@base_dir) || raise("bucket '#{@base_dir}' not found")
      end
    end
  end
end

