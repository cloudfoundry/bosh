require 'common/version_number'

##
# This module is in general unsafe to use as packages and jobs
# use their fingerprints as versions and therefore are not numerically
# comparable. At the moment releases retain a numerically comparable
# version which necessitates this code
module Bosh::Cli
  module VersionCalc

    # Returns 0 if two versions are the same,
    # 1 if version1 > version2
    # -1 if version1 < version2
    def version_cmp(version1 = "0", version2 = "0")
      Bosh::Common::VersionNumber.new(version1) <=> Bosh::Common::VersionNumber.new(version2)
    end

    def version_greater(version1, version2)
      version_cmp(version1, version2) > 0
    end

    def version_less(version1, version2)
      version_cmp(version1, version2) < 0
    end

    def version_same(version1, version2)
      version_cmp(version1, version2) == 0
    end

    def major_version(version)
      Bosh::Common::VersionNumber.new(version).major
    end

    def minor_version(version)
      Bosh::Common::VersionNumber.new(version).minor
    end

    def least_significant_version(version)
      Bosh::Common::VersionNumber.new(version).least_significant
    end
  end
end
