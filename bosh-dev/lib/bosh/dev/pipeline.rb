require 'fog'
require 'logger'

module Bosh::Dev
  class Pipeline
    attr_reader :fog_storage

    def initialize(options={})
      @fog_storage = options.fetch(:fog_storage) do
        fog_options = {
            provider: 'AWS',
            aws_access_key_id: ENV.to_hash.fetch('AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT'),
            aws_secret_access_key: ENV.to_hash.fetch('AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT')
        }
        Fog::Storage.new(fog_options)
      end
      @logger = options.fetch(:logger) { Logger.new(STDOUT) }
    end

    def create(options)
      base_directory.files.create(
          key: options.fetch(:key),
          body: options.fetch(:body),
          public: options.fetch(:public)
      )
    end

    def publish_stemcell(stemcell)
      latest_filename = latest_stemcell_filename(stemcell.infrastructure, stemcell.name, stemcell.light?)
      s3_latest_path = File.join(stemcell.name, stemcell.infrastructure, latest_filename)

      s3_path = File.join(stemcell.name, stemcell.infrastructure, File.basename(stemcell.path))
      s3_upload(stemcell.path, s3_path)
      s3_upload(stemcell.path, s3_latest_path)
    end

    def bucket
      'bosh-ci-pipeline'
    end

    def gems_dir_url
      "https://s3.amazonaws.com/#{bucket}/gems/"
    end

    def s3_upload(file, remote_path)
      directory = fog_storage.directories.get(bucket)
      directory.files.create(key: remote_path, body: File.open(file))
      logger.info("uploaded '#{file}' -> s3://#{bucket}/#{remote_path}")
    end

    def download_stemcell(version, options={})
      infrastructure = options.fetch(:infrastructure)
      name = options.fetch(:name)
      light = options.fetch(:light)

      filename = stemcell_filename(version, infrastructure, name, light)
      bucket_files = fog_storage.directories.get(bucket).files

      File.open(filename, 'w') do |file|
        bucket_files.get(File.join(name, infrastructure, filename)) do |chunk|
          file.write(chunk)
        end
      end

      logger.info("downloaded 's3://#{bucket}/#{File.join(name, infrastructure, filename)}' -> '#{filename}'")
    end

    def download_latest_stemcell(options={})
      infrastructure = options.fetch(:infrastructure)
      name = options.fetch(:name)
      light = options.fetch(:light, false)

      download_stemcell('latest', infrastructure: infrastructure, name: name, light: light)
    end

    def latest_stemcell_filename(infrastructure, name, light)
      stemcell_filename('latest', infrastructure, name, light)
    end

    private

    attr_reader :logger

    def base_directory
      fog_storage.directories.get(bucket) or raise "bucket '#{bucket}' not found"
    end

    def stemcell_filename(version, infrastructure, name, light)
      stemcell_filename_parts = []
      stemcell_filename_parts << version if version == 'latest'
      stemcell_filename_parts << 'light' if light
      stemcell_filename_parts << name
      stemcell_filename_parts << infrastructure
      stemcell_filename_parts << version unless version == 'latest'

      "#{stemcell_filename_parts.join('-')}.tgz"
    end
  end
end
