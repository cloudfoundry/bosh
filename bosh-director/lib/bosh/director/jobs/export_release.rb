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

        release = Bosh::Director::Models::Release.find(:name => @release_name)
        if release.nil?
          raise ReleaseNotFound
        end

        matching_versions = release.versions_dataset.where(:version => @release_version).all
        if matching_versions.empty?
          raise ReleaseVersionNotFound
        end

        logger.info "!!!RELEASE: #{release.pretty_inspect}"
      end
    end
  end
end
