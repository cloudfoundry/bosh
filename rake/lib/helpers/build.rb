module Bosh
  module Helpers
    class Build < Struct.new(:number)
      def self.current
        new(ENV.fetch('BUILD_NUMBER'))
      end

      def self.candidate
        new(ENV.fetch('CANDIDATE_BUILD_NUMBER'))
      end

      def s3_release_url
        "s3://bosh-ci-pipeline/bosh-#{number}.tgz"
      end
    end
  end
end
