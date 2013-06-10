module Bosh
  module Helpers
    class Build < Struct.new(:number, :job_name)
      attr_reader :number, :job_name

      def initialize(number)
        @number, @job_name = number, ENV.fetch('JOB_NAME')
      end

      def self.current
        new(ENV.fetch('BUILD_NUMBER'))
      end

      def self.candidate
        new(ENV.fetch('CANDIDATE_BUILD_NUMBER'))
      end

      def s3_release_url
        "s3://bosh-ci-pipeline/release/bosh-#{number}.tgz"
      end
    end
  end
end
