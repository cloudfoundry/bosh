module Bosh::Director
  module Jobs
    class DeleteRelease < BaseJob
      include LockHelper

      @queue = :normal

      def self.job_type
        :delete_release
      end

      def initialize(name, options = {})
        @name = name
        blobstore = options.fetch(:blobstore) { App.instance.blobstores.blobstore }
        blob_deleter = Helpers::BlobDeleter.new(blobstore, logger)
        @errors = []
        @force = !!options['force']
        @version = options['version']

        compiled_package_deleter = Helpers::CompiledPackageDeleter.new(blob_deleter, logger, event_log)
        @package_deleter = Helpers::PackageDeleter.new(compiled_package_deleter, blob_deleter, logger)
        @template_deleter = Helpers::TemplateDeleter.new(blob_deleter, logger)
        @release_version_deleter =
          Helpers::ReleaseVersionDeleter.new(@package_deleter, @template_deleter, @force, logger, event_log)
        @release_manager = Api::ReleaseManager.new
      end

      def perform
        logger.info('Processing delete release')

        with_release_lock(@name, :timeout => 10) do
          logger.info("Looking up release: #{@name}")
          release = @release_manager.find_by_name(@name)
          logger.info("Found release: #{release.name}")

          if @version
            logger.info("Looking up release version `#{release.name}/#{@version}'")
            release_version = @release_manager.find_version(release, @version)
            # found version may be different than the requested version, due to version formatting
            logger.info("Found release version: `#{release.name}/#{release_version.version}'")
            @release_version_deleter.delete(release_version, release)
          else
            logger.info('Checking for any deployments still using the release')
            deployments = release.versions.map { |version|
              version.deployments
            }.flatten.uniq

            unless deployments.empty?
              names = deployments.map { |d| d.name }.join(', ')
              raise ReleaseInUse,
                "Release `#{release.name}' is still in use by: #{names}"
            end

            delete_release(release)
          end
        end

        unless @errors.empty?
          errors = @errors.map { |e| e.to_s }.join(', ')
          raise ReleaseDeleteFailed, "Can't delete release: #{errors}"
        end

        "/release/#{@name}"
      end

      def delete_release(release)
        event_log.begin_stage('Deleting packages', release.packages.count)
        release.packages.each do |package|
          track_and_log("#{package.name}/#{package.version}") do
            @errors += @package_deleter.delete(package, @force)
          end
        end

        event_log.begin_stage('Deleting jobs', release.templates.count)
        release.templates.each do |template|
          track_and_log("#{template.name}/#{template.version}") do
            @errors += @template_deleter.delete(template, @force)
          end
        end

        if @errors.empty? || @force
          event_log.begin_stage('Deleting release versions', release.versions.count)

          release.versions.each do |release_version|
            track_and_log("#{release.name}/#{release_version.version}") do
              release_version.destroy
            end
          end

          release.destroy
        end
      end
    end
  end
end
