require 'peach'
require 'bosh/dev/promotable_artifacts'
require 'bosh/dev/download_adapter'
require 'bosh/dev/local_download_adapter'
require 'bosh/dev/upload_adapter'
require 'bosh/dev/bosh_release'
require 'bosh/dev/uri_provider'
require 'bosh/dev/gem_components'
require 'bosh/stemcell/archive'
require 'bosh/stemcell/archive_filename'
require 'bosh/stemcell/stemcell'
require 'logging'

module Bosh::Dev
  class Build
    attr_reader :number

    def self.candidate(bucket_name='bosh-ci-pipeline')
      logger = Logging.logger(STDERR)
      number = ENV['CANDIDATE_BUILD_NUMBER']
      if number
        logger.info("CANDIDATE_BUILD_NUMBER is #{number}. Using candidate build.")
        Candidate.new(number, bucket_name, DownloadAdapter.new(logger), logger)
      else
        logger.info('CANDIDATE_BUILD_NUMBER not set. Using local build.')

        subnum = ENV['STEMCELL_BUILD_NUMBER']
        if subnum
          logger.info("STEMCELL_BUILD_NUMBER is #{subnum}. Using local build with stemcell build number.")
        else
          logger.info('STEMCELL_BUILD_NUMBER not set. Using local build.')
          subnum = '0000'
        end

        Local.new(subnum, bucket_name, LocalDownloadAdapter.new(logger), logger)
      end
    end

    def initialize(number, bucket_name, download_adapter, logger)
      @number = number
      @logger = logger
      @promotable_artifacts = PromotableArtifacts.new(self, logger)
      @bucket = bucket_name
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
      upload_adapter.upload(
        bucket_name: bucket,
        key: File.join(number.to_s, release_path),
        body: File.open(release.final_tarball_path),
        public: true,
      )
    end

    def upload_stemcell(archive)
      normal_filename = File.basename(archive.path)
      latest_filename = normal_filename.gsub(/#{@number}/, 'latest')

      s3_path = File.join(number.to_s, 'bosh-stemcell', archive.infrastructure, normal_filename)
      s3_latest_path = File.join(number.to_s, 'bosh-stemcell', archive.infrastructure, latest_filename)

      upload_adapter = Bosh::Dev::UploadAdapter.new

      upload_adapter.upload(bucket_name: bucket, key: s3_latest_path, body: File.open(archive.path), public: true)
      logger.info("uploaded to s3://#{bucket}/#{s3_latest_path}")
      upload_adapter.upload(bucket_name: bucket, key: s3_path, body: File.open(archive.path), public: true)
      logger.info("uploaded to s3://#{bucket}/#{s3_path}")
    end

    def download_stemcell(stemcell, output_directory)
      remote_dir = File.join(number.to_s, 'bosh-stemcell', stemcell.infrastructure.name)
      download_adapter.download(UriProvider.pipeline_uri(remote_dir, stemcell.name), File.join(output_directory, stemcell.name))
      stemcell.name
    end

    def promote
      promotable_artifacts.all.peach do |artifact|
        if artifact.promoted?
          @logger.info("Skipping #{artifact.name} artifact promotion")
        else
          @logger.info("Executing #{artifact.name} artifact promotion")
          artifact.promote
        end
      end
    end

    def promoted?
      promotable_artifacts.all.all? { |artifact| artifact.promoted? }
    end

    private

    attr_reader :logger, :promotable_artifacts, :download_adapter, :upload_adapter, :bucket

    def release_path
      "release/#{promotable_artifacts.release_file}"
    end

    class Local < self
      def release_tarball_path
        release = BoshRelease.build
        GemComponents.new(@number).build_release_gems
        release.dev_tarball_path
      end

      def download_stemcell(stemcell, output_directory)
        download_adapter.download("tmp/#{stemcell.name}", File.join(output_directory, stemcell.name))
        stemcell.name
      end
    end

    class Candidate < self
      def release_tarball_path
        remote_dir = File.join(number.to_s, 'release')
        filename = promotable_artifacts.release_file
        source = UriProvider.pipeline_uri(remote_dir, filename)
        destination = "tmp/#{filename}"
        download_adapter.download(source, destination) unless File.exists?(destination)
        destination
      end
    end
  end
end
