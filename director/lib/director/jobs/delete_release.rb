module Bosh::Director
  module Jobs
    class DeleteRelease
      extend BaseJob

      @queue = :normal

      def initialize(name, options = {})
        @name = name
        @logger = Config.logger
        @blobstore = Config.blobstore
        @errors = []
        @force = options["force"] || false
      end

      def delete_release(release)
        @logger.info("Deleting release")
        release.versions.each do |release_version|
          @logger.info("Deleting release version: #{release_version.pretty_inspect}")
          release_version.templates.each do |template|
            @logger.info("Deleting template: #{template.pretty_inspect}")
            delete_blobstore_id(template.blobstore_id) { template.delete }
            @logger.info("Deleted template: #{template.pretty_inspect}")
          end

          release_version.packages.each do |package|
            @logger.info("Deleting package: #{package.pretty_inspect}")
            compiled_packages = package.compiled_packages
            compiled_packages.each do |compiled_package|
              @logger.info("Deleting compiled package: #{compiled_package.pretty_inspect}")
              delete_blobstore_id(compiled_package.blobstore_id) { compiled_package.delete }
            end

            delete_blobstore_id(package.blobstore_id) { package.delete }
            @logger.info("Deleted package: #{package.pretty_inspect}")
          end

          if @errors.empty? || @force
            release_version.delete
            @logger.info("Deleted release version: #{release_version.pretty_inspect}")
          end
        end

        if @errors.empty? || @force
          release.delete
          @logger.info("Deleted release")
        end
      end

      def perform
        @logger.info("Processing delete release")

        lock = Lock.new("lock:release:#{@name}", :timeout => 10)
        lock.lock do
          @logger.info("Looking up release: #{@name}")
          release = Models::Release.find(:name => @name).first
          raise ReleaseNotFound.new(@name) if release.nil?
          @logger.info("Found: #{release.pretty_inspect}")

          @logger.info("Checking for any deployments still using the release..")
          unless release.deployments.empty?
            deployments = []
            release.deployments.each { |deployment| deployments << deployment.name }
            raise ReleaseInUse.new(@name, deployments.join(", "))
          end

          delete_release(release)
        end

        unless @errors.empty?
          raise "Error deleting release: #{@errors.collect { |e| e.to_s }.join(",")}"
        end

        "/release/#{@name}"
      end

      def delete_blobstore_id(blobstore_id)
        deleted = false
        begin
          @blobstore.delete(blobstore_id)
          deleted = true
        rescue Exception => e
          @logger.warn("Could not delete from blobstore: #{e} - #{e.backtrace.join("\n")}")
          @errors << e
        end
        yield if deleted || @force
      end

    end
  end
end
