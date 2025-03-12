module Bosh::Director
  module DeploymentPlan
    class ReleaseVersionExportedFrom
      extend ValidationHelper

      attr_reader :os
      attr_reader :version

      def self.parse(spec)
        os = safe_property(spec, 'os', class: String)
        version = safe_property(spec, 'version', class: String)

        new(os, version)
      end

      def initialize(os, version)
        @os = os
        @version = version
      end

      def compatible_with?(stemcell)
        return false unless stemcell.os == os

        Bosh::Version::StemcellVersion.match(version, stemcell.version)
      end
    end
  end
end
