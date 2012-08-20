# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    class UpdateRelease < BaseJob
      @queue = :normal

      # TODO: remove these, only being used in tests, better to refactor tests
      attr_accessor :release_model
      attr_accessor :tmp_release_dir

      # @param [String] tmp_release_dir Directory containing release bundle
      # @param [Hash] options Release update options
      def initialize(tmp_release_dir, options = {})
        super

        @tmp_release_dir = tmp_release_dir
        @release_model = nil
        @release_version_model = nil

        @rebase = !!options[:rebase]

        @manifest = nil
        @name = nil
        @version = nil
      end

      # Extracts release tarball, verifies release manifest and saves release
      # in DB
      # @return [void]
      def perform
        logger.info("Processing update release")

        event_log.begin_stage("Updating release", 3)
        track_and_log("Extracting release") { extract_release }
        track_and_log("Verifying manifest") { verify_manifest }
        track_and_log("Save release version") do
          release_lock = Lock.new("lock:release:#{@name}")
          release_lock.lock { process_release }
        end

        "Created release `#{@name}/#{@version}'"
      rescue Exception => e
        remove_release_version_model
        raise e
      ensure
        if @tmp_release_dir && File.exists?(@tmp_release_dir)
          FileUtils.rm_rf(@tmp_release_dir)
        end
        # TODO: delete task status file or cleanup later?
      end

      # Extracts release tarball
      # @return [void]
      def extract_release
        release_tgz = File.join(@tmp_release_dir,
                                Api::ReleaseManager::RELEASE_TGZ)

        tar_output = `tar -C #{@tmp_release_dir} -xzf #{release_tgz} 2>&1`

        if $?.exitstatus != 0
          raise ReleaseInvalidArchive,
                "Invalid release archive, tar returned #{$?.exitstatus}, " +
                "tar output: #{tar_output}"
        end
      ensure
        if release_tgz && File.exists?(release_tgz)
          FileUtils.rm(release_tgz)
        end
      end

      # @return [void]
      def verify_manifest
        manifest_file = File.join(@tmp_release_dir, "release.MF")
        unless File.file?(manifest_file)
          raise ReleaseManifestNotFound, "Release manifest not found"
        end

        @manifest = YAML.load_file(manifest_file)
        normalize_manifest

        @name = @manifest["name"]
        @version = @manifest["version"]

        # TODO: make sure all jobs are there
        # TODO: make sure there are no extra jobs

        # TODO: make sure all packages are there
        # TODO: make sure there are no extra packages
      end

      # Processes uploaded release, creates jobs and packages in DB if needed
      # @return [void]
      def process_release
        @release_model = Models::Release.find_or_create(:name => @name)

        version_attrs = {
          :release => @release_model,
          :version => @version
        }

        @release_version_model = Models::ReleaseVersion.new(version_attrs)
        unless @release_version_model.valid?
          raise ReleaseAlreadyExists,
                "Release `#{@name}/#{@version}' already exists"
        end

        @release_version_model.save

        resolve_package_dependencies(@manifest["packages"])

        @packages = {}
        process_packages
        process_jobs
      end

      # Normalizes release manifest, so all names, versions, and checksums
      # are Strings.
      # @return [void]
      def normalize_manifest
        %w(name version).each do |property|
          @manifest[property] = @manifest[property].to_s
        end

        @manifest["packages"].each do |package_meta|
          %w(name version sha1).each do |property|
            package_meta[property] = package_meta[property].to_s
          end
        end

        @manifest["jobs"].each do |job_meta|
          %w(name version sha1).each do |property|
            job_meta[property] = job_meta[property].to_s
          end
        end
      end

      # Resolves package dependencies, makes sure there are no cycles
      # and all dependencies are present
      # TODO: cleanup exceptions raised by CycleHelper
      # @return [void]
      def resolve_package_dependencies(packages)
        packages_by_name = {}
        packages.each do |package|
          packages_by_name[package["name"]] = package
          package["dependencies"] ||= []
        end
        dependency_lookup = lambda do |package_name|
          packages_by_name[package_name]["dependencies"]
        end
        result = CycleHelper.check_for_cycle(packages_by_name.keys,
                                             :connected_vertices => true,
                                             &dependency_lookup)

        packages.each do |package|
          name = package["name"]
          dependencies = package["dependencies"]

          logger.info("Resolving package dependencies for `#{name}', " +
                      "found: #{dependencies.pretty_inspect}")
          package["dependencies"] = result[:connected_vertices][name]
          logger.info("Resolved package dependencies for `#{name}', " +
                      "to: #{dependencies.pretty_inspect}")
        end
      end

      # Finds all package definitions in the manifest and sorts them into two
      # buckets: new and existing packages, then creates new packages and points
      # current release version to the existing packages.
      # @return [void]
      def process_packages
        logger.info("Checking for new packages in release")

        new_packages = []
        existing_packages = []

        @manifest["packages"].each do |package_meta|
          package_attrs = {:sha1 => package_meta["sha1"]}

          # Search for existing packages
          packages = Models::Package.filter(package_attrs).all

          if packages.nil? || packages.empty?
            new_packages << package_meta
          else
            # We can reuse an existing package as long as it
            # belongs to the same release and has the same name and version
            package = packages.find do |package|
              package.release_id == @release_model.id &&
              package.name == package_meta["name"] &&
              package.version == package_meta["version"]
            end

            if package
              existing_packages << [package, package_meta]
            else
              # We found a package but not in the same release, so
              # make a copy of the package blob and create a new db entry for it
              package = packages.first
              logger.info("Release #{@release_model.id} now using package" +
                          "#{package.inspect}")
              package_meta["blobstore_id"] = package.blobstore_id
              new_packages << package_meta
            end
          end
        end

        create_packages(new_packages)
        use_existing_packages(existing_packages)
      end

      # Creates packages using provided metadata
      # @param [Array<Hash>] packages Packages metadata
      # @return [void]
      def create_packages(packages)
        return if packages.empty?

        event_log.begin_stage("Creating new packages", packages.size)
        packages.each do |package_meta|
          package_desc = "#{package_meta["name"]}/#{package_meta["version"]}"
          event_log.track(package_desc) do
            logger.info("Creating new package `#{package_desc}'")
            package = create_package(package_meta)
            register_package(package)
          end
        end
      end

      # Points release DB model to existing packages described by given metadata
      # @param [Array<Array>] packages Existing packages metadata
      def use_existing_packages(packages)
        return if packages.empty?

        n_packages = packages.size
        event_log.begin_stage("Processing #{n_packages} existing " +
                              "package#{n_packages > 1 ? "s" : ""}", 1)

        event_log.track("Verifying checksums") do
          packages.each do |package, package_meta|
            package_desc = "#{package.name}/#{package.version}"
            logger.info("Package `#{package_desc}' already exists, " +
                        "verifying checksum")

            # TODO: make sure package dependencies have not changed
            expected = package.sha1
            received = package_meta["sha1"]

            if expected != received
              raise ReleaseExistingPackageHashMismatch,
                    "`#{package_desc}' checksum mismatch, " +
                      "expected #{expected} but received #{received}"
            end
            logger.info("Package `#{package_desc}' verified")
            register_package(package)
          end
        end
      end

      # Creates package in DB according to given metadata
      # @param [Hash] package_meta Package metadata
      # @return [void]
      def create_package(package_meta)
        package_attrs = {
          :release => @release_model,
          :name => package_meta["name"],
          :version => package_meta["version"],
          :sha1 => package_meta["sha1"]
        }

        package = Models::Package.new(package_attrs)
        package.dependency_set = package_meta["dependencies"]

        existing_blob = package_meta["blobstore_id"]

        if existing_blob
          logger.info("Copying blob #{existing_blob} " +
                      "for #{package.name}/#{package_meta["version"]}")
          package.blobstore_id = BlobUtil.copy_blob(existing_blob)
        else
          logger.info("Creating package: #{package.name}")

          package_tgz = File.join(@tmp_release_dir, "packages",
                                  "#{package.name}.tgz")

          output = `tar -tzf #{package_tgz} 2>&1`
          if $?.exitstatus != 0
            raise PackageInvalidArchive,
                  "Invalid package archive, tar returned #{$?.exitstatus} " +
                  "tar output: #{output}"
          end

          # TODO: verify sha1
          package.blobstore_id = BlobUtil.create_blob(package_tgz)
        end

        package.save
      end

      # Marks package model as used by release version model
      # @param [Models::Package] package Package model
      # @return [void]
      def register_package(package)
        @packages[package.name] = package
        @release_version_model.add_package(package)
      end

      # Finds job template definitions in release manifest and sorts them into
      # two buckets: new and existing job templates, then creates new job
      # template records in the database and points release version to existing
      # ones.
      # @return [void]
      def process_jobs
        logger.info("Checking for new jobs in release")

        new_jobs = []
        existing_jobs = []

        @manifest["jobs"].each do |job_meta|
          template_attrs = {
            :release_id => @release_model.id,
            :name => job_meta["name"],
            :version => job_meta["version"]
          }

          template = Models::Template[template_attrs]
          if template.nil?
            new_jobs << job_meta
          else
            existing_jobs << [template, job_meta]
          end
        end

        create_jobs(new_jobs)
        use_existing_jobs(existing_jobs)
      end

      def create_jobs(jobs)
        return if jobs.empty?

        event_log.begin_stage("Creating new jobs", jobs.size)
        jobs.each do |job_meta|
          job_desc = "#{job_meta["name"]}/#{job_meta["version"]}"
          event_log.track(job_desc) do
            logger.info("Creating new template `#{job_desc}'")
            template = create_job(job_meta)
            register_template(template)
          end
        end
      end

      def create_job(job_meta)
        template_attrs = {
          :release => @release_model,
          :name => job_meta["name"],
          :version => job_meta["version"],
          :sha1 => job_meta["sha1"]
        }

        template = Models::Template.new(template_attrs)

        logger.info("Processing job: #{template.name}")
        job_tgz = File.join(@tmp_release_dir, "jobs", "#{template.name}.tgz")
        job_dir = File.join(@tmp_release_dir, "jobs", "#{template.name}")

        FileUtils.mkdir_p(job_dir)

        output = `tar -C #{job_dir} -xzf #{job_tgz} 2>&1`

        if $?.exitstatus != 0
          raise JobInvalidArchive,
                "Invalid job archive for `#{template.name}', " +
                "tar returned #{$?.exitstatus}, " +
                "tar output: #{output}"
        end

        manifest_file = File.join(job_dir, "job.MF")
        unless File.file?(manifest_file)
          raise JobMissingManifest,
                "Missing job manifest for `#{template.name}'"
        end

        job_manifest = YAML.load_file(manifest_file)

        if job_manifest["templates"]
          job_manifest["templates"].each_key do |relative_path|
            path = File.join(job_dir, "templates", relative_path)
            unless File.file?(path)
              raise JobMissingTemplateFile,
                    "Missing template file `#{relative_path}' " +
                    "for job `#{template.name}'"
            end
          end
        end

        main_monit_file = File.join(job_dir, "monit")
        aux_monit_files = Dir.glob(File.join(job_dir, "*.monit"))

        unless File.exists?(main_monit_file) || aux_monit_files.size > 0
          raise JobMissingMonit, "Job `#{template.name}' is missing monit file"
        end

        # TODO: verify sha1
        template.blobstore_id = BlobUtil.create_blob(job_tgz)

        package_names = []
        job_manifest["packages"].each do |package_name|
          package = @packages[package_name]
          if package.nil?
            raise JobMissingPackage,
                  "Job `#{template.name}' is referencing " +
                  "a missing package `#{package_name}'"
          end
          package_names << package.name
        end
        template.package_names = package_names

        if job_manifest["logs"]
          unless job_manifest["logs"].is_a?(Hash)
            raise JobInvalidLogSpec,
                  "Job `#{template.name}' has invalid logs spec format"
          end

          template.logs = job_manifest["logs"]
        end

        template.save
      end

      # @param [Array<Array>] jobs Existing jobs metadata
      # @return [void]
      def use_existing_jobs(jobs)
        return if jobs.empty?

        n_jobs = jobs.size
        event_log.begin_stage("Processing #{n_jobs} existing " +
                                "job#{n_jobs > 1 ? "s" : ""}", 1)

        event_log.track("Verifying checksums") do
          jobs.each do |template, job_meta|
            job_desc = "#{template.name}/#{template.version}"

            logger.info("Job `#{job_desc}' already exists, " +
                        "verifying checksum")

            expected = template.sha1
            received = job_meta["sha1"]

            if expected != received
              raise ReleaseExistingJobHashMismatch,
                    "`#{job_desc}' checksum mismatch, " +
                    "expected #{expected} but received #{received}"
            end

            logger.info("Job `#{job_desc}' verified")
            register_template(template)
          end
        end
      end

      # Marks job template model as being used by release version
      # @param [Models::Template] template Job template model
      # @return [void]
      def register_template(template)
        @release_version_model.add_template(template)
      end

      private
      # TODO: can make most of other methods private as well but first need to
      # refactor tests for that

      # Removes release version model, along with all packages and templates.
      # @return [void]
      def remove_release_version_model
        return unless @release_version_model && !@release_version_model.new?

        @release_version_model.remove_all_packages
        @release_version_model.remove_all_templates
        @release_version_model.destroy
      end
    end
  end
end