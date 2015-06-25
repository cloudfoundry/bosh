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

      def initialize(deployment_name, release_name, release_version, stemcell_os, stemcell_version, options = {})
        @deployment_name = deployment_name
        @release_name = release_name
        @release_version = release_version
        @stemcell_os = stemcell_os
        @stemcell_version = stemcell_version
      end


      # @return [void]
      def perform
        logger.info("Exporting release: #{@release_name}/#{@release_version} for #{@stemcell_os}/#{@stemcell_version}")

        release_manager = Bosh::Director::Api::ReleaseManager.new
        release = release_manager.find_by_name(@release_name)
        release_manager.find_version(release, @release_version)

      end
    end
  end
end
