# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    class UpdateRelease < BaseJob
      @queue = :normal

      attr_accessor :tmp_release_dir
      attr_accessor :release

      def initialize(release_dir)
        super

        @tmp_release_dir = release_dir
        @blobstore = Config.blobstore
        @release = nil
      end

      def perform
        logger.info("Processing update release")
        event_log.begin_stage("Updating release", 3)

        extract_release
        verify_manifest

        release_lock = Lock.new("lock:release:#{@release_name}")
        release_lock.lock { process_release }

        "/releases/#{@release_name}/#{@release_version}"
      rescue Exception => e
        # cleanup
        if @release_version_entry && !@release_version_entry.new?
          @release_version_entry.remove_all_packages
          @release_version_entry.remove_all_templates
          @release_version_entry.destroy
        end
        raise e
      ensure
        FileUtils.rm_rf(@tmp_release_dir) if File.exists?(@tmp_release_dir)
        # TODO: delete task status file or cleanup later?
      end

      def extract_release
        track_and_log("Extracting release") do
          begin
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
        end
      end

      def verify_manifest
        track_and_log("Verifying manifest") do
          manifest_file = File.join(@tmp_release_dir, "release.MF")
          unless File.file?(manifest_file)
            raise ReleaseManifestNotFound, "Release manifest not found"
          end

          @release_manifest = YAML.load_file(manifest_file)
          normalize_manifest

          @release_name = @release_manifest["name"]
          @release_version = @release_manifest["version"]
        end

        # TODO: make sure all jobs are there
        # TODO: make sure there are no extra jobs

        # TODO: make sure all packages are there
        # TODO: make sure there are no extra packages
      end

      def process_release
        @release = Models::Release.find_or_create(:name => @release_name)

        track_and_log("Save release version") do
          version_attrs = {
            :release => @release,
            :version => @release_version
          }
          desc = "#{@release_name}/#{@release_version}"

          @release_version_entry = Models::ReleaseVersion.new(version_attrs)
          unless @release_version_entry.valid?
            raise ReleaseAlreadyExists, "Release #{desc} already exists"
          end
          @release_version_entry.save
        end

        resolve_package_dependencies(@release_manifest["packages"])

        @packages = {}
        process_packages

        process_jobs
      end

      def normalize_manifest
        %w(name version).each do |property|
          @release_manifest[property] = @release_manifest[property].to_s
        end

        @release_manifest["packages"].each do |package_meta|
          %w(name version sha1).each do |property|
            package_meta[property] = package_meta[property].to_s
          end
        end

        @release_manifest["jobs"].each do |job_meta|
          %w(name version sha1).each do |property|
            job_meta[property] = job_meta[property].to_s
          end
        end
      end

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

      def process_packages
        logger.info("Checking for new packages in release")

        new_packages = []
        existing_packages = []

        @release_manifest["packages"].each do |package_meta|
          package_attrs = {
            :release_id => @release.id,
            :name => package_meta["name"],
            :version => package_meta["version"]
          }

          package = Models::Package[package_attrs]
          if package.nil?
            new_packages << package_meta
          else
            existing_packages << [package, package_meta]
          end
        end

        if new_packages.size > 0
          event_log.begin_stage("Creating new packages", new_packages.size)
          new_packages.each do |package_meta|
            package_desc = "#{package_meta["name"]}/#{package_meta["version"]}"
            event_log.track(package_desc) do
              logger.info("Creating new package `#{package_desc}'")
              package = create_package(package_meta)
              register_package(package)
            end
          end
        end

        if existing_packages.size > 0
          n_packages = existing_packages.size
          event_log.begin_stage("Processing #{n_packages} existing " +
                                "package#{n_packages > 1 ? "s" : ""}", 1)

          event_log.track("Verifying checksums") do
            existing_packages.each do |package, package_meta|
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
      end

      def register_package(package)
        @packages[package.name] = package
        @release_version_entry.add_package(package)
      end

      def process_jobs
        logger.info("Checking for new jobs in release")

        new_jobs = []
        existing_jobs = []

        @release_manifest["jobs"].each do |job_meta|
          template_attrs = {
            :release_id => @release.id,
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

        if new_jobs.size > 0
          event_log.begin_stage("Creating new jobs", new_jobs.size)
          new_jobs.each do |job_meta|
            job_desc = "#{job_meta["name"]}/#{job_meta["version"]}"
            event_log.track(job_desc) do
              logger.info("Creating new template `#{job_desc}'")
              template = create_job(job_meta)
              register_template(template)
            end
          end
        end

        if existing_jobs.size > 0
          n_jobs = existing_jobs.size
          event_log.begin_stage("Processing #{n_jobs} existing " +
                                "job#{n_jobs > 1 ? "s" : ""}", 1)

          event_log.track("Verifying checksums") do
            existing_jobs.each do |template, job_meta|
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
      end

      def register_template(template)
        @release_version_entry.add_template(template)
      end

      def create_package(package_meta)
        package_attrs = {
          :release => @release,
          :name => package_meta["name"],
          :version => package_meta["version"],
          :sha1 => package_meta["sha1"]
        }

        package = Models::Package.new(package_attrs)
        package.dependency_set = package_meta["dependencies"]

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
        File.open(package_tgz) do |f|
          package.blobstore_id = @blobstore.create(f)
        end

        package.save
      end

      def create_job(job_meta)
        template_attrs = {
          :release => @release,
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
        File.open(job_tgz) do |f|
          template.blobstore_id = @blobstore.create(f)
        end

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
    end
  end
end
