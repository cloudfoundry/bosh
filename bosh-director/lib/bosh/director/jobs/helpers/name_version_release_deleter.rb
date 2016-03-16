module Bosh::Director::Jobs
  module Helpers
    class NameVersionReleaseDeleter
      def initialize(release_deleter, release_manager, release_version_deleter, logger)
        @release_deleter = release_deleter
        @release_manager = release_manager
        @release_version_deleter = release_version_deleter
        @logger = logger
      end

      def find_and_delete_release(name, version, force)
        @logger.info("Looking up release: #{name}")
        release = @release_manager.find_by_name(name)
        @logger.info("Found release: #{release.name}")

        if version
          delete_release_version(release, version, force)
        else
          delete_entire_release(release, force)
        end
      end

      private

      def delete_entire_release(release, force)
        @logger.info('Checking for any deployments still using the release')
        deployments = release.versions.map { |version|
          version.deployments
        }.flatten.uniq

        unless deployments.empty?
          names = deployments.map { |d| d.name }.join(', ')
          raise Bosh::Director::ReleaseInUse,
            "Release '#{release.name}' is still in use by: #{names}"
        end
        @release_deleter.delete(release, force)
      end

      def delete_release_version(release, version, force)
        @logger.info("Looking up release version '#{release.name}/#{version}'")
        release_version = @release_manager.find_version(release, version)
        # found version may be different than the requested version, due to version formatting
        @logger.info("Found release version: '#{release.name}/#{release_version.version}'")
        @release_version_deleter.delete(release_version, release, force)
      end
    end
  end
end
