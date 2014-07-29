require 'common/version/semi_semantic_version'

module Bosh::Common
  module Version
    class StemcellVersion < SemiSemanticVersion

      def self.parse(version)
        raise ArgumentError, 'Invalid Version: nil' if version.nil?
        version = version.to_s

        #replace underscores with periods to maintain reverse compatibility with stemcell versions
        version = version.gsub('_', '.')

        self.new(SemiSemantic::Version.parse(version))
      end

      private

      def default_post_release_segment
        raise NotImplementedError, 'Stemcell post-release versions unsupported'
      end
    end
  end
end
