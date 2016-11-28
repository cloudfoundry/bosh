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
        @force = !!options['force']
        @version = options['version']

        blobstore = options.fetch(:blobstore) { App.instance.blobstores.blobstore }
        compiled_package_deleter = Helpers::CompiledPackageDeleter.new(blobstore, logger)
        package_deleter = Helpers::PackageDeleter.new(compiled_package_deleter, blobstore, logger)
        template_deleter = Helpers::TemplateDeleter.new(blobstore, logger)
        release_deleter = Helpers::ReleaseDeleter.new(package_deleter, template_deleter, Config.event_log, logger)
        release_version_deleter =
          Helpers::ReleaseVersionDeleter.new(release_deleter, package_deleter, template_deleter, logger, Config.event_log)
        release_manager = Api::ReleaseManager.new
        @name_version_release_deleter = Helpers::NameVersionReleaseDeleter.new(release_deleter, release_manager, release_version_deleter, logger)
      end

      def perform
        logger.info('Processing delete release')

        with_release_lock(@name, :timeout => 10) do
          @name_version_release_deleter.find_and_delete_release(@name, @version, @force)
        end

        "/release/#{@name}"
      end
    end
  end
end
