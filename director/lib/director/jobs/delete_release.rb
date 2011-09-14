module Bosh::Director
  module Jobs
    class DeleteRelease < BaseJob

      @queue = :normal

      def initialize(name, options = {})
        super
        @name = name
        @blobstore = Config.blobstore
        @errors = []
        @force = options["force"] || false
        @version = options["version"]

      end

      def delete_release_version(release_version)
        @event_log.begin_stage("Deleting release version", 1, [ @name, @version ].reject {|x| !x})
        track_and_log("Deleting release") do
          @logger.info("Deleting release #{@name} version #{@version}")
        end

        release = release_version.release

        packages_to_keep = []
        packages_to_delete = []
        templates_to_keep = []
        templates_to_delete = []

        # We don't delete packages inside this loop b/c Sequel will also delete
        # them from packages collection we're iterating on which will lead to
        # skipping some packages
        release_version.packages.each do |package|
          if package.release_versions == [ release_version ]
            packages_to_delete << package
          else
            packages_to_keep << package
          end
        end

        release_version.templates.each do |template|
          if template.release_versions == [ release_version ]
            templates_to_delete << template
          else
            templates_to_keep << template
          end
        end

        @event_log.begin_stage("Deleting packages", packages_to_delete.count)
        packages_to_delete.each do |package|
          track_and_log("Deleting package #{package.name}/#{package.version}") do
            @logger.info("Package #{package.name}/#{package.version} is only used by this release version and will be deleted")
            delete_package(package)
          end
        end

        packages_to_keep.each do |package|
          @logger.info("Keeping package #{package.name}/#{package.version} as it is used by other release versions")
          package.remove_release_version(release_version)
        end

        @event_log.begin_stage("Deleting templates", templates_to_delete.count)
        templates_to_delete.each do |template|
          track_and_log("Deleting template #{template.name}/#{template.version}") do
            @logger.info("Template #{template.name}/#{template.version} is only used by this release version and will be deleted")
            delete_template(template)
          end
        end

        templates_to_keep.each do |template|
          @logger.info("Keeping template #{template.name}/#{template.version} as it is used by other release versions")
          template.remove_release_version(release_version)
        end

        @logger.info("Remove all deployments in release version")
        release_version.remove_all_deployments

        if @errors.empty? || @force
          release_version.destroy
        end

        if release.versions.empty?
          delete_release(release)
        end
      end

      def delete_release(release)
        @event_log.begin_stage("Deleting release", 1, [ @name ])
        track_and_log("Deleting release") do
          @logger.info("Deleting release #{@name}")
        end

        @event_log.begin_stage("Deleting release", release.packages.count)
        release.packages.each do |package|
          track_and_log("Deleting package #{package.name}/#{package.version}") do
            delete_package(package)
          end
        end

        release.templates.each do |template|
          track_and_log("Deleting template #{template.name}/#{template.version}") do
            delete_template(template)
          end
        end

        if @errors.empty? || @force
          release.versions.each { |release_version| release_version.destroy }
          release.destroy
        end
      end

      def delete_package(package)
        compiled_packages = package.compiled_packages

        @logger.info("Deleting package #{package.name}/#{package.version}")

        compiled_packages.each do |compiled_package|
          stemcell = compiled_package.stemcell
          @logger.info("Deleting compiled package (#{compiled_package.blobstore_id}) #{package.name}/#{package.version} for #{stemcell.name}/#{stemcell.version}")
          delete_blobstore_id(compiled_package.blobstore_id) { compiled_package.destroy }
        end

        @logger.info("Deleting package (#{package.blobstore_id}) #{package.name}/#{package.version}")
        delete_blobstore_id(package.blobstore_id) do
          package.remove_all_release_versions
          package.destroy
        end
      end

      def delete_template(template)
        @logger.info("Deleting template: #{template.name}/#{template.version}")

        delete_blobstore_id(template.blobstore_id) do
          template.remove_all_release_versions
          template.destroy
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

          if @version
            @logger.info("Looking up release version: #{@version}")
            release_version = release.versions_dataset.filter(:version => @version).first
            raise ReleaseVersionNotFound.new(@name, @version) if release_version.nil?

            @logger.info("Found: #{release.name}/#{release_version.version}")
            @logger.info("Checking for any deployments still using this particular release version")

            unless release_version.deployments.empty?
              raise ReleaseVersionInUse.new(@name, @version, release_version.deployments.map{ |d| d.name }.join(", "))
            end

            delete_release_version(release_version)

          else
            @logger.info("Checking for any deployments still using the release")
            unless release.deployments.empty?
              raise ReleaseInUse.new(@name, release.deployments.map { |d| d.name }.join(", "))
            end

            delete_release(release)
          end
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
