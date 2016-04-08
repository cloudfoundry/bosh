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
        blob_deleter = Helpers::BlobDeleter.new(blobstore, logger)
        compiled_package_deleter = Helpers::CompiledPackageDeleter.new(blob_deleter, logger)
        package_deleter = Helpers::PackageDeleter.new(compiled_package_deleter, blob_deleter, logger)
        template_deleter = Helpers::TemplateDeleter.new(blob_deleter, logger)
        release_deleter = Helpers::ReleaseDeleter.new(package_deleter, template_deleter, Config.event_log, logger)
        release_version_deleter =
          Helpers::ReleaseVersionDeleter.new(release_deleter, package_deleter, template_deleter, logger, Config.event_log)
        release_manager = Api::ReleaseManager.new
        @name_version_release_deleter = Helpers::NameVersionReleaseDeleter.new(release_deleter, release_manager, release_version_deleter, logger)
      end

      def perform
        logger.info('Processing delete release')

        errors = nil

        with_release_lock(@name, :timeout => 10) do
          errors = @name_version_release_deleter.find_and_delete_release(@name, @version, @force)
        end

        unless errors.empty?
          error_strings = errors.map { |e| e.to_s }.join(', ')
          raise ReleaseDeleteFailed, "Can't delete release: #{error_strings}"
        end

        "/release/#{@name}"
      end
    end
  end
end
