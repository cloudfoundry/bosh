require 'fog'
require 'logger'

require 'bosh/dev/build'
require 'bosh/stemcell/infrastructure'
require 'bosh/dev/pipeline_storage'
require 'bosh/stemcell/archive_filename'

module Bosh::Dev
  class Pipeline
    attr_reader :storage

    def initialize(options = {})
      @storage = options.fetch(:storage) { Bosh::Dev::PipelineStorage.new }
      @build_id = options.fetch(:build_id) { Build.candidate.number.to_s }
      @logger = options.fetch(:logger) { Logger.new($stdout) }
      @bucket = 'bosh-ci-pipeline'
    end

    def upload_r(source_dir, dest_dir)
      Dir.chdir(source_dir) do
        Dir['**/*'].each do |file|
          unless File.directory?(file)
            key = File.join(build_id, dest_dir, file)
            uploaded_file = storage.upload(
              bucket,
              key,
              File.open(file),
              true
            )
            logger.info("uploaded to #{uploaded_file.public_url || "s3://#{bucket}/#{build_id}/#{key}"}")
          end
        end
      end
    end

    def publish_stemcell(stemcell)
      Build.candidate.upload_stemcell(stemcell)
    end

    def gems_dir_url
      Build.candidate.gems_dir_url
    end

    private

    attr_reader :logger, :bucket, :build_id
  end
end
