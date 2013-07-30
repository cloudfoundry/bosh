require 'bosh/dev/pipeline'
require 'bosh/dev/infrastructure'

module Bosh::Dev
  class Build
    attr_reader :number

    def self.candidate
      if ENV.fetch('JOB_NAME') == 'publish_candidate_gems'
        new(ENV.fetch('BUILD_NUMBER'))
      else
        new(ENV.fetch('CANDIDATE_BUILD_NUMBER'))
      end
    end

    def initialize(number)
      @number = number
      @job_name = ENV.fetch('JOB_NAME')
      @pipeline = Pipeline.new(build_id: number.to_s)
    end

    def upload(release)
      pipeline.s3_upload(release.tarball, release_path)
    end

    def download_release
      command = "s3cmd --verbose -f get #{s3_release_url} #{release_path}"
      Rake::FileUtilsExt.sh(command) || raise("Command failed: #{command}")

      release_path
    end

    def s3_release_url
      File.join(pipeline.s3_url, release_path)
    end

    def promote_artifacts(aws_credentials)
      sync_buckets
      update_light_micro_bosh_ami_pointer_file(aws_credentials[:access_key_id], aws_credentials[:secret_access_key])
    end

    def sync_buckets
      Rake::FileUtilsExt.sh("s3cmd --verbose sync #{File.join(pipeline.s3_url, 'gems/')} s3://bosh-jenkins-gems")

      Rake::FileUtilsExt.sh("s3cmd --verbose sync #{File.join(pipeline.s3_url, 'release')} s3://bosh-jenkins-artifacts")
      Rake::FileUtilsExt.sh("s3cmd --verbose sync #{File.join(pipeline.s3_url, 'bosh-stemcell')} s3://bosh-jenkins-artifacts")
      Rake::FileUtilsExt.sh("s3cmd --verbose sync #{File.join(pipeline.s3_url, 'micro-bosh-stemcell')} s3://bosh-jenkins-artifacts")
    end

    def update_light_micro_bosh_ami_pointer_file(access_key_id, secret_access_key)
      infrastructure = Infrastructure.for('aws')
      pipeline.download_stemcell(number.to_s, infrastructure: infrastructure, name: 'micro-bosh-stemcell', light: true)

      stemcell = Bosh::Dev::Stemcell.new(pipeline.stemcell_filename(number.to_s, infrastructure, 'micro-bosh-stemcell', true))

      connection = fog_storage(access_key_id, secret_access_key)
      directory = connection.directories.create(key: 'bosh-jenkins-artifacts')
      directory.files.create(key: 'last_successful_micro-bosh-stemcell-aws_ami_us-east-1',
                             body: stemcell.ami_id,
                             acl: 'public-read')
    end

    def fog_storage(access_key_id, secret_access_key)
      Fog::Storage.new(provider: 'AWS',
                       aws_access_key_id: access_key_id,
                       aws_secret_access_key: secret_access_key)
    end

    private

    attr_reader :pipeline, :job_name

    def release_path
      "release/bosh-#{number}.tgz"
    end
  end
end
