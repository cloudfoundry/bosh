require 'peach'

require 'bosh/dev/promote_artifacts'
require 'bosh/dev/download_adapter'
require 'bosh/dev/upload_adapter'
require 'bosh/stemcell/archive'
require 'bosh/stemcell/archive_filename'
require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'

module Bosh::Dev
  class Build
    attr_reader :number

    def self.candidate
      env_hash = ENV.to_hash
      new(number: env_hash.fetch('CANDIDATE_BUILD_NUMBER'))
    end

    def initialize(options)
      @number = options.fetch(:number)
      @logger = Logger.new($stdout)
      @promoter = PromoteArtifacts.new(self)
    end

    def upload(release, options = {})
      bucket = 'bosh-ci-pipeline'
      key = File.join(number.to_s, release_path)
      upload_adapter = options.fetch(:upload_adapter) { UploadAdapter.new }
      upload_adapter.upload(bucket_name: bucket, key: key, body: File.open(release.tarball), public: true)
    end

    def upload_gems(source_dir, dest_dir)
      bucket = 'bosh-ci-pipeline'
      upload_adapter = Bosh::Dev::UploadAdapter.new
      Dir.chdir(source_dir) do
        Dir['**/*'].each do |file|
          unless File.directory?(file)
            key = File.join(number.to_s, dest_dir, file)
            uploaded_file = upload_adapter.upload(bucket_name: bucket, key: key, body: File.open(file), public: true)
            logger.info("uploaded to #{uploaded_file.public_url || "s3://#{bucket}/#{number}/#{key}"}")
          end
        end
      end
    end

    def download_release(options = {})
      download_adapter = options.fetch(:download_adapter) { DownloadAdapter.new }
      output_directory = options.fetch(:output_directory) { Dir.pwd }

      remote_dir = File.join(number.to_s, 'release')
      filename = promoter.release_file

      download_adapter.download(uri(remote_dir, filename), File.join(output_directory, release_path))

      release_path
    end

    def download_stemcell(options = {})
      infrastructure = options.fetch(:infrastructure)
      name = options.fetch(:name)
      light = options.fetch(:light)
      download_adapter = options.fetch(:download_adapter) { DownloadAdapter.new }
      output_directory = options.fetch(:output_directory) { Dir.pwd }

      filename = stemcell_filename(number.to_s, infrastructure, name, light)
      remote_dir = File.join(number.to_s, name, infrastructure.name)

      download_adapter.download(uri(remote_dir, filename), File.join(output_directory, filename))

      filename
    end

    def upload_stemcell(stemcell)
      latest_filename = stemcell_filename('latest', Bosh::Stemcell::Infrastructure.for(stemcell.infrastructure), stemcell.name, stemcell.light?)
      s3_latest_path = File.join(number.to_s, stemcell.name, stemcell.infrastructure, latest_filename)
      s3_path = File.join(number.to_s, stemcell.name, stemcell.infrastructure, File.basename(stemcell.path))

      bucket = 'bosh-ci-pipeline'
      upload_adapter = Bosh::Dev::UploadAdapter.new

      upload_adapter.upload(bucket_name: bucket, key: s3_latest_path, body: File.open(stemcell.path), public: false)
      logger.info("uploaded to s3://#{bucket}/#{s3_latest_path}")
      upload_adapter.upload(bucket_name: bucket, key: s3_path, body: File.open(stemcell.path), public: false)
      logger.info("uploaded to s3://#{bucket}/#{s3_path}")
    end

    def promote_artifacts
      sync_buckets
      update_light_bosh_ami_pointer_file
    end

    def bosh_stemcell_path(infrastructure, download_dir)
      File.join(download_dir, stemcell_filename(number.to_s, infrastructure, 'bosh-stemcell', infrastructure.light?))
    end

    private

    attr_reader :logger, :promoter

    def sync_buckets
      promoter.commands.peach do |cmd|
        Rake::FileUtilsExt.sh(cmd)
      end
    end

    def update_light_bosh_ami_pointer_file
      Bosh::Dev::UploadAdapter.new.upload(
        bucket_name: 'bosh-jenkins-artifacts',
        key: 'last_successful-bosh-stemcell-aws_ami_us-east-1',
        body: light_stemcell.ami_id,
        public: true
      )
    end

    def light_stemcell
      infrastructure = Bosh::Stemcell::Infrastructure.for('aws')
      download_stemcell(infrastructure: infrastructure, name: 'bosh-stemcell', light: true)
      filename = stemcell_filename(number.to_s, infrastructure, 'bosh-stemcell', true)
      Bosh::Stemcell::Archive.new(filename)
    end

    def release_path
      "release/#{promoter.release_file}"
    end

    def stemcell_filename(version, infrastructure, name, light)
      operating_system = Bosh::Stemcell::OperatingSystem.for('ubuntu')
      Bosh::Stemcell::ArchiveFilename.new(version, infrastructure, operating_system, name, light).to_s
    end

    def uri(remote_directory_path, file_name)
      remote_file_path = File.join(remote_directory_path, file_name)
      URI.parse("http://bosh-ci-pipeline.s3.amazonaws.com/#{remote_file_path}")
    end
  end
end
