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
        @blobstore = options.fetch(:blobstore) { App.instance.blobstores.blobstore }
        @errors = []
        @force = !!options['force']
        @version = options['version']
        @compiled_package_deleter = Helpers::CompiledPackageDeleter.new(@blobstore, logger, event_log)
        @release_manager = Api::ReleaseManager.new
      end

      def delete_release(release)
        event_log.begin_stage('Deleting packages', release.packages.count)
        release.packages.each do |package|
          track_and_log("#{package.name}/#{package.version}") do
            delete_package(package)
          end
        end

        event_log.begin_stage('Deleting jobs', release.templates.count)
        release.templates.each do |template|
          track_and_log("#{template.name}/#{template.version}") do
            delete_template(template)
          end
        end

        if @errors.empty? || @force
          event_log.begin_stage('Deleting release versions',
            release.versions.count)

          release.versions.each do |release_version|
            track_and_log("#{release.name}/#{release_version.version}") do
              release_version.destroy
            end
          end

          release.destroy
        end
      end

      def delete_package(package)
        compiled_packages = package.compiled_packages

        logger.info("Deleting package #{package.name}/#{package.version}")

        compiled_packages.each do |compiled_package|
          begin
            @compiled_package_deleter.delete(compiled_package, {'force' => @force})
          rescue Exception => e
            @errors << e
          end
        end

        if delete_blobstore_id(package.blobstore_id, true)
          package.remove_all_release_versions
          package.destroy
        end
      end

      def delete_template(template)
        logger.info("Deleting job: #{template.name}/#{template.version}")

        if delete_blobstore_id(template.blobstore_id)
          template.remove_all_release_versions
          template.destroy
        end
      end


      def delete_blobstore_id(blobstore_id, nil_id_allowed = false)
        if blobstore_id.nil? && nil_id_allowed
          return true
        end

        deleted = false
        begin
          @blobstore.delete(blobstore_id)
          deleted = true
        rescue Exception => e
          logger.warn("Could not delete from blobstore: #{e}\n " + e.backtrace.join("\n"))
          @errors << e
        end

        return deleted || @force
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
            package_deleter = Helpers::PackageDeleter.new(@compiled_package_deleter, @blobstore, logger)
            release_version_deleter = Helpers::ReleaseVersionDeleter.new(@blobstore, package_deleter, @force, logger, event_log)
            release_version_deleter.delete(release_version, release)
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
    end
  end
end
