module Bosh::Cli::Versions
  class ReleaseVersionsIndex

    def initialize(versions_index)
      @versions_index = versions_index
    end

    def latest_version
      version_strings = @versions_index.version_strings
      return nil if version_strings.empty?
      Bosh::Common::Version::ReleaseVersionList.parse(version_strings).latest
    end

    def versions
      Bosh::Common::Version::ReleaseVersionList.parse(@versions_index.version_strings)
    end
  end
end
