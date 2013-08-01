require 'fog'
require 'logger'

require 'bosh/dev/stemcell_filename'

module Bosh::Dev
  class Pipeline
    attr_reader :fog_storage

    def initialize(options = {})
      @fog_storage = options.fetch(:fog_storage) do
        fog_options = {
            provider: 'AWS',
            aws_access_key_id: ENV.to_hash.fetch('AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT'),
            aws_secret_access_key: ENV.to_hash.fetch('AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT')
        }
        Fog::Storage.new(fog_options)
      end
      @build_id = options.fetch(:build_id) { Build.candidate.number.to_s }
      @logger = options.fetch(:logger) { Logger.new($stdout) }
      @bucket = 'bosh-ci-pipeline'
    end

    def create(options)
      uploaded_file = base_directory.files.create(
          key: File.join(build_id, options.fetch(:key)),
          body: options.fetch(:body),
          public: options.fetch(:public)
      )
      logger.info("uploaded to #{uploaded_file.public_url || File.join(s3_url, options.fetch(:key))}")
    end

    def publish_stemcell(stemcell)
      format = stemcell.light? ? 'ami' : 'image'
      infrastructure = Infrastructure.for(stemcell.infrastructure)

      latest_filename = stemcell_filename(
          version: 'latest',
          infrastructure: infrastructure.name,
          format: format,
          hypervisor: infrastructure.hypervisor,
      )

      s3_latest_path = File.join(stemcell.name, stemcell.infrastructure, latest_filename)

      s3_path = File.join(stemcell.name, stemcell.infrastructure, File.basename(stemcell.path))
      s3_upload(stemcell.path, s3_path)
      s3_upload(stemcell.path, s3_latest_path)
    end

    def gems_dir_url
      "https://s3.amazonaws.com/#{bucket}/#{build_id}/gems/"
    end

    def s3_upload(file, remote_path)
      create(key: remote_path, body: File.open(file), public: false)
    end

    def download_stemcell(version, options = {})
      format = options.fetch(:light) ? 'ami' : 'image'
      infrastructure = options.fetch(:infrastructure)
      name = options.fetch(:name)

      filename = stemcell_filename(
          name: name,
          version: version,
          infrastructure: infrastructure.name,
          format: format,
          hypervisor: infrastructure.hypervisor,
      )
      bucket_files = fog_storage.directories.get(bucket).files
      remote_path = File.join(build_id, name, infrastructure.name, filename)
      raise "remote stemcell '#{filename}' not found" unless bucket_files.head(remote_path)

      File.open(filename, 'w') do |file|
        bucket_files.get(remote_path) do |chunk|
          file.write(chunk)
        end
      end

      logger.info("downloaded 's3://#{bucket}/#{remote_path}' -> '#{filename}'")
    end

    def stemcell_filename(options)
      StemcellFilename.new(options).filename
    end

    def s3_url
      "s3://#{bucket}/#{build_id}/"
    end

    def bosh_stemcell_path(infrastructure, download_dir)
      format = infrastructure.light? ? 'ami' : 'image'

      filename = stemcell_filename(
          version: build_id,
          infrastructure: infrastructure.name,
          format: format,
          hypervisor: infrastructure.hypervisor,
      )

      File.join(download_dir, filename)
    end

    def micro_bosh_stemcell_path(infrastructure, download_dir)
      format = infrastructure.light? ? 'ami' : 'image'

      filename = stemcell_filename(
          name: 'micro_stemcell',
          version: build_id,
          infrastructure: infrastructure.name,
          format: format,
          hypervisor: infrastructure.hypervisor,
      )

      File.join(download_dir, filename)
    end

    def fetch_stemcells(infrastructure, download_dir)
      Dir.chdir(download_dir) do
        download_stemcell(build_id, infrastructure: infrastructure, name: 'micro_stemcell', light: infrastructure.light?)
        download_stemcell(build_id, infrastructure: infrastructure, name: 'stemcell', light: infrastructure.light?)
      end
    end

    def cleanup_stemcells(download_dir)
      FileUtils.rm_f(Dir.glob(File.join(download_dir, '*bosh-stemcell-*.tgz')))
    end

    private

    attr_reader :logger, :bucket, :build_id

    def base_directory
      fog_storage.directories.get(bucket) || raise("bucket '#{bucket}' not found")
    end
  end
end
