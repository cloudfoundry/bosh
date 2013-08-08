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
      @storage = options.fetch(:storage) { default_storage }
      @build_id = options.fetch(:build_id) { Build.candidate.number.to_s }
      @logger = options.fetch(:logger) { Logger.new($stdout) }
      @bucket = 'bosh-ci-pipeline'
    end

    def create(options)
      uploaded_file = storage.upload(
        bucket,
        File.join(build_id, options.fetch(:key)),
        options.fetch(:body),
        options.fetch(:public)
      )
      logger.info("uploaded to #{uploaded_file.public_url || File.join(s3_url, options.fetch(:key))}")
    end

    def publish_stemcell(stemcell)
      latest_filename = stemcell_filename('latest', Bosh::Stemcell::Infrastructure.for(stemcell.infrastructure), stemcell.name, stemcell.light?)
      s3_latest_path = File.join(stemcell.name, stemcell.infrastructure, latest_filename)

      s3_path = File.join(stemcell.name, stemcell.infrastructure, File.basename(stemcell.path))

      create(key: s3_path, body: File.open(stemcell.path), public: false)
      create(key: s3_latest_path, body: File.open(stemcell.path), public: false)
    end

    def gems_dir_url
      "https://s3.amazonaws.com/#{bucket}/#{build_id}/gems/"
    end

    def download_stemcell(options = {})
      infrastructure = options.fetch(:infrastructure)
      name = options.fetch(:name)
      light = options.fetch(:light)

      filename = stemcell_filename(build_id, infrastructure, name, light)

      remote_dir = File.join(build_id, name, infrastructure.name)

      download(remote_dir, filename)

      filename
    end

    def bosh_stemcell_path(infrastructure, download_dir)
      File.join(download_dir, stemcell_filename(build_id, infrastructure, 'bosh-stemcell', infrastructure.light?))
    end

    def micro_bosh_stemcell_path(infrastructure, download_dir)
      File.join(download_dir, stemcell_filename(build_id, infrastructure, 'micro-bosh-stemcell', infrastructure.light?))
    end

    def cleanup_stemcells(download_dir)
      FileUtils.rm_f(Dir.glob(File.join(download_dir, '*bosh-stemcell-*.tgz')))
    end

    private

    attr_reader :logger, :bucket, :build_id

    def s3_url
      "s3://#{bucket}/#{build_id}/"
    end

    def stemcell_filename(version, infrastructure, name, light)
      Bosh::Stemcell::ArchiveFilename.new(version, infrastructure, name, light).to_s
    end

    def download(remote_dir, filename)
      storage.download(bucket, remote_dir, filename)

      remote_path = File.join(remote_dir, filename)
      logger.info("downloaded 's3://#{bucket}/#{remote_path}' -> '#{filename}'")
    end

    def default_storage
      Bosh::Dev::PipelineStorage.new
    end
  end
end
