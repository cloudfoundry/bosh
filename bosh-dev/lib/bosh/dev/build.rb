require 'bosh/dev/pipeline'

module Bosh
  module Dev
    class Build < Struct.new(:number, :job_name)
      attr_reader :number, :job_name

      def initialize(number)
        @number, @job_name = number, ENV.fetch('JOB_NAME')
        @pipeline = Pipeline.new
      end

      def self.current
        new(ENV.fetch('BUILD_NUMBER'))
      end

      def self.candidate
        new(ENV.fetch('CANDIDATE_BUILD_NUMBER'))
      end

      def upload(release)
        pipeline.s3_upload(release.tarball, s3_release_url)
      end

      def s3_release_url
        File.join(Pipeline.new.base_url, "release/bosh-#{number}.tgz")
      end

      private
      attr_reader :pipeline
    end
  end
end
