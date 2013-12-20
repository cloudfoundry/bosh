require 'peach'
require 'logger'
require 'bosh/dev/promotable_artifacts'
require 'bosh/dev/light_stemcell_pointer'
require 'bosh/dev/download_adapter'
require 'bosh/dev/local_download_adapter'
require 'bosh/dev/upload_adapter'
require 'bosh/dev/bosh_release'
require 'bosh/dev/uri_provider'
require 'bosh/stemcell/archive'
require 'bosh/stemcell/archive_filename'
require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'

module Bosh::Dev
  class Build
    attr_reader :number

    def self.candidate(logger = Logger.new(STDERR))
      number = ENV['CANDIDATE_BUILD_NUMBER']
      if number
        logger.info("CANDIDATE_BUILD_NUMBER is #{number}. Using candidate build.")
        Candidate.new(number, DownloadAdapter.new(logger))
      else
        logger.info('CANDIDATE_BUILD_NUMBER not set. Using local build.')
        Local.new('local', LocalDownloadAdapter.new(logger))
      end
    end

    def initialize(number, download_adapter)
      @number = number
      @logger = Logger.new($stdout)
      @promotable_artifacts = PromotableArtifacts.new(self)
      @bucket = 'bosh-ci-pipeline'
      @upload_adapter = UploadAdapter.new
      @download_adapter = download_adapter
    end

    def upload_gems(source_dir, dest_dir)
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

    def upload_release(release)
      key = File.join(number.to_s, release_path)
      upload_adapter.upload(bucket_name: bucket, key: key, body: File.open(release.tarball_path), public: true)
    end

    def upload_stemcell(stemcell)
      normal_filename = File.basename(stemcell.path)
      latest_filename = normal_filename.gsub(/#{@number}/, 'latest')

      s3_path = File.join(number.to_s, 'bosh-stemcell', stemcell.infrastructure, normal_filename)
      s3_latest_path = File.join(number.to_s, 'bosh-stemcell', stemcell.infrastructure, latest_filename)

      bucket = 'bosh-ci-pipeline'
      upload_adapter = Bosh::Dev::UploadAdapter.new

      upload_adapter.upload(bucket_name: bucket, key: s3_latest_path, body: File.open(stemcell.path), public: true)
      logger.info("uploaded to s3://#{bucket}/#{s3_latest_path}")
      upload_adapter.upload(bucket_name: bucket, key: s3_path, body: File.open(stemcell.path), public: true)
      logger.info("uploaded to s3://#{bucket}/#{s3_path}")
    end

    def download_stemcell(name, infrastructure, operating_system, light, output_directory)
      filename   = Bosh::Stemcell::ArchiveFilename.new(
        number.to_s, infrastructure, operating_system, name, light).to_s
      remote_dir = File.join(number.to_s, name, infrastructure.name)
      download_adapter.download(UriProvider.pipeline_uri(remote_dir, filename), File.join(output_directory, filename))
      filename
    end

    def promote_artifacts
      promotable_artifacts.all.peach do |artifact|
        artifact.promote
      end
    end

    def bosh_stemcell_path(infrastructure, operating_system, download_dir)
      File.join(download_dir, Bosh::Stemcell::ArchiveFilename.new(
        number.to_s,
        infrastructure,
        operating_system,
        'bosh-stemcell',
        infrastructure.light?,
      ).to_s)
    end

    def light_stemcell
      name = 'bosh-stemcell'
      infrastructure = Bosh::Stemcell::Infrastructure.for('aws')
      operating_system = Bosh::Stemcell::OperatingSystem.for('ubuntu')
      filename = download_stemcell(name, infrastructure, operating_system, true, Dir.pwd)
      Bosh::Stemcell::Archive.new(filename)
    end

    private

    attr_reader :logger, :promotable_artifacts, :download_adapter, :upload_adapter, :bucket

    def release_path
      "release/#{promotable_artifacts.release_file}"
    end

    class Local < self
      def release_tarball_path
        release = BoshRelease.build
        release.tarball_path
      end

      def download_stemcell(name, infrastructure, operating_system, light, output_directory)
        filename = Bosh::Stemcell::ArchiveFilename.new(
          number.to_s, infrastructure, operating_system, name, light).to_s
        download_adapter.download("tmp/#{filename}", File.join(output_directory, filename))
        filename
      end
    end

    class Candidate < self
      def release_tarball_path
        remote_dir = File.join(number.to_s, 'release')
        filename = promotable_artifacts.release_file
        downloaded_release_path = "tmp/#{promotable_artifacts.release_file}"
        download_adapter.download(UriProvider.pipeline_uri(remote_dir, filename), downloaded_release_path)
        downloaded_release_path
      end
    end
  end
end
