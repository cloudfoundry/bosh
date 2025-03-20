require 'bosh/version/semi_semantic_version'
require 'bosh/version/parse_error'

module Bosh
  module Version
    class StemcellVersion < SemiSemanticVersion

      def self.parse(version)
        raise ArgumentError, 'Invalid Version: nil' if version.nil?
        version = version.to_s

        #replace underscores with periods to maintain reverse compatibility with stemcell versions
        version = version.gsub('_', '.')

        self.new(SemiSemantic::Version.parse(version))
      rescue SemiSemantic::ParseError => e
        raise ParseError.new(e)
      end

      def self.match(str_a, str_b)
        version_a, version_b = parse(str_a), parse(str_b)
        version_a.matches(version_b)
      end

      def matches(other)
        release_self = self.version.release
        release_other = other.version.release
        release_self.components[0] == release_other.components[0]
      end

      private

      def default_post_release_segment
        raise NotImplementedError, 'Stemcell post-release versions unsupported'
      end
    end
  end
end
