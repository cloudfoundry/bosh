require 'securerandom'
require 'common/version/release_version'

module Bosh::Director
  module Jobs
    class ExportRelease < BaseJob
      include LockHelper

      @queue = :normal

      def self.job_type
        :export_release
      end

      def initialize(release_name, release_version, stemcell_os, stemcell_version, options = {})
      #   DO some initilization
        logger.info("we are in ExportRelease:initialize #{release_name}/#{release_version} #{stemcell_os}/#{stemcell_version}")
      end

      # @return [void]
      def perform
        logger.info("we are in ExportRelease:perform")
      end
    end
  end
end
