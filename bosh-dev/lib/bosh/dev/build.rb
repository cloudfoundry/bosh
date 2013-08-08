require 'bosh/stemcell/stemcell'
require 'bosh/stemcell/archive_filename'
require 'bosh/stemcell/infrastructure'
require 'bosh/dev/download_adapter'
require 'bosh/dev/upload_adapter'
require 'bosh/dev/pipeline_storage'

module Bosh::Dev
  class Build
    attr_reader :number

    def self.candidate
      env_hash = ENV.to_hash

      if env_hash.fetch('JOB_NAME') == 'publish_candidate_gems'
        new(env_hash.fetch('BUILD_NUMBER'))
      else
        new(env_hash.fetch('CANDIDATE_BUILD_NUMBER'))
      end
    end

    def initialize(number)
      @number = number
      @job_name = ENV.to_hash.fetch('JOB_NAME')
      @logger = Logger.new($stdout)
    end

    def upload(release, options = {})
      bucket = 'bosh-ci-pipeline'
      key = File.join(number.to_s, release_path)
      upload_adapter = options.fetch(:upload_adapter) { UploadAdapter.new }
      upload_adapter.upload(bucket_name: bucket, key: key, body: File.open(release.tarball), public: true)
    end

    def download_release
      command = "s3cmd --verbose -f get #{s3_release_url} #{release_path}"
      Rake::FileUtilsExt.sh(command) || raise("Command failed: #{command}")

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
      s3_latest_path = File.join(stemcell.name, stemcell.infrastructure, latest_filename)
      s3_path = File.join(stemcell.name, stemcell.infrastructure, File.basename(stemcell.path))

      create(key: s3_path, body: File.open(stemcell.path), public: false)
      create(key: s3_latest_path, body: File.open(stemcell.path), public: false)
    end

    def s3_release_url
      File.join(s3_url, release_path)
    end

    def gems_dir_url
      "https://s3.amazonaws.com/bosh-ci-pipeline/#{number}/gems/"
    end

    def promote_artifacts(aws_credentials)
      sync_buckets
      update_light_micro_bosh_ami_pointer_file(aws_credentials)
    end

    def sync_buckets
      Rake::FileUtilsExt.sh("s3cmd --verbose sync #{File.join(s3_url, 'gems/')} s3://bosh-jenkins-gems")

      Rake::FileUtilsExt.sh("s3cmd --verbose sync #{File.join(s3_url, 'release')} s3://bosh-jenkins-artifacts")
      Rake::FileUtilsExt.sh("s3cmd --verbose sync #{File.join(s3_url, 'bosh-stemcell')} s3://bosh-jenkins-artifacts")
      Rake::FileUtilsExt.sh("s3cmd --verbose sync #{File.join(s3_url, 'micro-bosh-stemcell')} s3://bosh-jenkins-artifacts")
    end

    def update_light_micro_bosh_ami_pointer_file(aws_credentials)
      connection = fog_storage(aws_credentials[:access_key_id], aws_credentials[:secret_access_key])
      directory = connection.directories.create(key: 'bosh-jenkins-artifacts')
      directory.files.create(key: 'last_successful_micro-bosh-stemcell-aws_ami_us-east-1',
                             body: light_stemcell.ami_id,
                             acl: 'public-read')
    end

    def fog_storage(access_key_id, secret_access_key)
      Fog::Storage.new(provider: 'AWS',
                       aws_access_key_id: access_key_id,
                       aws_secret_access_key: secret_access_key)
    end

    def bosh_stemcell_path(infrastructure, download_dir)
      File.join(download_dir, stemcell_filename(number.to_s, infrastructure, 'bosh-stemcell', infrastructure.light?))
    end

    def micro_bosh_stemcell_path(infrastructure, download_dir)
      File.join(download_dir, stemcell_filename(number.to_s, infrastructure, 'micro-bosh-stemcell', infrastructure.light?))
    end

    private

    attr_reader :job_name, :logger

    def create(options)
      bucket = 'bosh-ci-pipeline'
      uploaded_file = Bosh::Dev::PipelineStorage.new.upload(
        bucket,
        File.join(number.to_s, options.fetch(:key)),
        options.fetch(:body),
        options.fetch(:public)
      )
      logger.info("uploaded to #{uploaded_file.public_url || "s3://#{bucket}/#{number}/#{options.fetch(:key)}"}")
    end

    def light_stemcell
      infrastructure = Bosh::Stemcell::Infrastructure.for('aws')
      download_stemcell(infrastructure: infrastructure, name: 'micro-bosh-stemcell', light: true)
      filename = stemcell_filename(number.to_s, infrastructure, 'micro-bosh-stemcell', true)
      Bosh::Stemcell::Stemcell.new(filename)
    end

    def release_path
      "release/bosh-#{number}.tgz"
    end

    def s3_url
      "s3://bosh-ci-pipeline/#{number}/"
    end

    def stemcell_filename(version, infrastructure, name, light)
      Bosh::Stemcell::ArchiveFilename.new(version, infrastructure, name, light).to_s
    end

    def uri(remote_directory_path, file_name)
      remote_file_path = File.join(remote_directory_path, file_name)
      URI.parse("http://bosh-ci-pipeline.s3.amazonaws.com/#{remote_file_path}")
    end
  end
end
