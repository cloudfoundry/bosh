require 'peach'

require 'bosh/dev/promote_artifacts'
require 'bosh/dev/download_adapter'
require 'bosh/dev/upload_adapter'
require 'bosh/dev/micro_bosh_release'
require 'bosh/stemcell/archive'
require 'bosh/stemcell/archive_filename'
require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'

module Bosh::Dev
  class Build
    attr_reader :number

    def self.candidate
      candidate_build_number = ENV['CANDIDATE_BUILD_NUMBER']
      if candidate_build_number
        Candidate.new(number: candidate_build_number)
      else
        Local.new
      end
    end

    def initialize(options)
      @number = options.fetch(:number)
      @logger = Logger.new($stdout)
      @promoter = PromoteArtifacts.new(self)
      @bucket = 'bosh-ci-pipeline'
      @upload_adapter = UploadAdapter.new
      @download_adapter = DownloadAdapter.new
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
      upload_adapter.upload(bucket_name: bucket, key: key, body: File.open(release.tarball), public: true)
    end

    def upload_stemcell(stemcell)
      infrastructure = Bosh::Stemcell::Infrastructure.for(stemcell.infrastructure)

      normal_filename = stemcell_filename(@number, infrastructure, 'bosh-stemcell', stemcell.light?)
      latest_filename = stemcell_filename('latest', infrastructure, 'bosh-stemcell', stemcell.light?)

      s3_path = File.join(number.to_s, 'bosh-stemcell', stemcell.infrastructure, normal_filename)
      s3_latest_path = File.join(number.to_s, 'bosh-stemcell', stemcell.infrastructure, latest_filename)

      bucket = 'bosh-ci-pipeline'
      upload_adapter = Bosh::Dev::UploadAdapter.new

      upload_adapter.upload(bucket_name: bucket, key: s3_latest_path, body: File.open(stemcell.path), public: false)
      logger.info("uploaded to s3://#{bucket}/#{s3_latest_path}")
      upload_adapter.upload(bucket_name: bucket, key: s3_path, body: File.open(stemcell.path), public: false)
      logger.info("uploaded to s3://#{bucket}/#{s3_path}")
    end

    def download_stemcell(options = {})
      infrastructure = options.fetch(:infrastructure)
      name = options.fetch(:name)
      light = options.fetch(:light)
      output_directory = options.fetch(:output_directory) { Dir.pwd }

      filename = stemcell_filename(number.to_s, infrastructure, name, light)
      remote_dir = File.join(number.to_s, name, infrastructure.name)

      download_adapter.download(uri(remote_dir, filename), File.join(output_directory, filename))

      filename
    end

    def promote_artifacts
      sync_buckets
      update_light_bosh_ami_pointer_file
    end

    def bosh_stemcell_path(infrastructure, download_dir)
      File.join(download_dir, stemcell_filename(number.to_s, infrastructure, 'bosh-stemcell', infrastructure.light?))
    end

    private

    attr_reader :logger, :promoter, :download_adapter, :upload_adapter, :bucket

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

    class Local < self
      def initialize
        super(number: 'local')
      end

      def release_tarball_path
        release = MicroBoshRelease.new
        release.tarball
      end
    end

    class Candidate < self
      def release_tarball_path
        remote_dir = File.join(number.to_s, 'release')
        filename = promoter.release_file
        downloaded_release_path = "tmp/#{promoter.release_file}"

        download_adapter.download(uri(remote_dir, filename), downloaded_release_path)

        downloaded_release_path
      end
    end
  end
end
