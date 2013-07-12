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
        File.join("s3://#{pipeline.bucket}/", "release/bosh-#{number}.tgz")
      end

      def sync_buckets
        Rake::FileUtilsExt.sh('s3cmd sync s3://bosh-ci-pipeline/gems/ s3://bosh-jenkins-gems')
        Rake::FileUtilsExt.sh('s3cmd sync s3://bosh-ci-pipeline/release s3://bosh-jenkins-artifacts')
        Rake::FileUtilsExt.sh('s3cmd sync s3://bosh-ci-pipeline/bosh-stemcell s3://bosh-jenkins-artifacts')
        Rake::FileUtilsExt.sh('s3cmd sync s3://bosh-ci-pipeline/micro-bosh-stemcell s3://bosh-jenkins-artifacts')
      end

      private
      attr_reader :pipeline, :job_name
    end
  end
end
