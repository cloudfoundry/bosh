require 'semi_semantic/version'

module Bosh::Director
  class NextRebaseVersion

    # See Bosh::Common::VersionNumber.parse_list to parse a list of strings
    def initialize(existing_versions)
      existing_versions.each { |v| raise TypeError, "Invalid Version Type: #{v.class}" unless v.is_a?(SemiSemantic::Version) }
      @existing_versions = existing_versions
    end

    def calculate(version)
      raise TypeError, "Invalid Version Type: #{version.class}" unless version.is_a?(SemiSemantic::Version)

      # Only rebase post-release versions
      return version if version.post_release.nil?

      # Find the latest existing version with the same release and pre-release segments as the provided version
      latest = @existing_versions.select { |v|
        v.release == version.release && v.pre_release == version.pre_release
      }.max

      if latest
        if latest.post_release.nil?
          SemiSemantic::Version.new(latest.release, latest.pre_release, Bosh::Common::VersionNumber::DEFAULT_DEV_RELEASE_SEGMENT)
        else
          SemiSemantic::Version.new(latest.release, latest.pre_release, latest.post_release.increment)
        end
      else
        SemiSemantic::Version.new(version.release, version.pre_release, Bosh::Common::VersionNumber::DEFAULT_DEV_RELEASE_SEGMENT)
      end
    end
  end
end
