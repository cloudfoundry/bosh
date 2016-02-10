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

      def self.match_patch_versions(str_a, str_b)
        version_a, version_b = parse(str_a), parse(str_b)
        version_a.matches_patch_version(version_b)
      end

      def matches_patch_version(other)
        return true if self == other

        release_self = self.version.release
        release_other = other.version.release

        min_size = [release_self.components.size, release_other.components.size].min
        cut_point = [0, min_size - 2].max

        trimmed_self = release_self.components[0..cut_point].join('.')
        trimmed_other = release_other.components[0..cut_point].join('.')

        self.class.parse(trimmed_self) == self.class.parse(trimmed_other)
      end

      private

      def default_post_release_segment
        raise NotImplementedError, 'Stemcell post-release versions unsupported'
      end
    end
  end
end
