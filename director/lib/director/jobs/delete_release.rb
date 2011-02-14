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
        @logger.info("Deleting release: #{@name}")

        release.packages.each do |package|
          @logger.info("Deleting package: #{package.name}/#{package.version}")
          compiled_packages = package.compiled_packages
          compiled_packages.each do |compiled_package|
            stemcell = compiled_package.stemcell
            @logger.info("Deleting compiled package: #{package.name}/#{package.version} for " +
                             "#{stemcell.name}/#{stemcell.version}")
            delete_blobstore_id(compiled_package.blobstore_id) { compiled_package.destroy }
          end
          delete_blobstore_id(package.blobstore_id) do
            package.remove_all_release_versions
            package.destroy
          end
        end

        release.templates.each do |template|
          @logger.info("Deleting template: #{template.name}/#{template.version}")
          delete_blobstore_id(template.blobstore_id) do
            template.remove_all_release_versions
            template.destroy
          end
        end

        if @errors.empty? || @force
          release.versions.each { |release_version| release_version.destroy }
          release.destroy
        end
      end

      def perform
        @logger.info("Processing delete release")

        lock = Lock.new("lock:release:#{@name}", :timeout => 10)
        lock.lock do
          @logger.info("Looking up release: #{@name}")
          release = Models::Release[:name => @name]
          raise ReleaseNotFound.new(@name) if release.nil?
          @logger.info("Found: #{release.name}")

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
