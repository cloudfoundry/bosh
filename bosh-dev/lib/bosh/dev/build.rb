require 'bosh/dev/pipeline'

module Bosh
  module Dev
    class Build
      attr_reader :number

      def initialize(number)
        @number = number
        @job_name = ENV.fetch('JOB_NAME')
        @pipeline = Pipeline.new
      end

      def self.current
        new(ENV.fetch('BUILD_NUMBER'))
      end

      def self.candidate
        new(ENV.fetch('CANDIDATE_BUILD_NUMBER'))
      end

      def upload(release)
        pipeline.s3_upload(release.tarball, "release/bosh-#{number}.tgz")
      end

      def s3_release_url
        File.join(s3_pipeline_uri, "release/bosh-#{number}.tgz")
      end

      def sync_buckets
        Rake::FileUtilsExt.sh("s3cmd sync #{File.join(s3_pipeline_uri, 'gems')} s3://bosh-jenkins-gems")

        Rake::FileUtilsExt.sh("s3cmd sync #{File.join(s3_pipeline_uri, 'release')} s3://bosh-jenkins-artifacts")
        Rake::FileUtilsExt.sh("s3cmd sync #{File.join(s3_pipeline_uri, 'bosh-stemcell')} s3://bosh-jenkins-artifacts")
        Rake::FileUtilsExt.sh("s3cmd sync #{File.join(s3_pipeline_uri, 'micro-bosh-stemcell')} s3://bosh-jenkins-artifacts")
      end

      def update_light_micro_bosh_ami_pointer_file(aws_credentials)
        pipeline.download_latest_stemcell(infrastructure: 'aws', name: 'micro-bosh-stemcell', light: true)

        stemcell = Bosh::Dev::Stemcell.new(pipeline.latest_stemcell_filename('aws', 'micro-bosh-stemcell', true))

        connection = fog_storage(aws_credentials[:access_key_id], aws_credentials[:secret_access_key])
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

      def s3_pipeline_uri
        "s3://#{pipeline.bucket}/"
      end
    end
  end
end
