require 'common/version_number'

##
# This module is in general unsafe to use as packages and jobs
# use their fingerprints as versions and therefore are not numerically
# comparable. At the moment releases retain a numerically comparable
# version which necessitates this code
module Bosh::Cli
  module VersionCalc

    # Returns 0 if two versions are the same,
    # 1 if v1 > v2
    # -1 if v1 < v2
    def version_cmp(v1 = "0", v2 = "0")
      Bosh::Common::VersionNumber.new(v1) <=> Bosh::Common::VersionNumber.new(v2)
    end

    def version_greater(v1, v2)
      version_cmp(v1, v2) > 0
    end

    def version_less(v1, v2)
      version_cmp(v1, v2) < 0
    end

    def version_same(v1, v2)
      version_cmp(v1, v2) == 0
    end

    def major_version(v)
      Bosh::Common::VersionNumber.new(v).major
    end

    def minor_version(v)
      Bosh::Common::VersionNumber.new(v).minor
    end
  end
end
