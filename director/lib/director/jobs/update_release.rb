module Bosh::Director
  module Jobs
    class UpdateRelease < BaseJob

      @queue = :normal

      attr_accessor :tmp_release_dir, :release

      def initialize(*args)
        super

        if args.length == 1
          release_dir = args.first
          @tmp_release_dir = release_dir
          @blobstore = Config.blobstore
        elsif args.empty?
          # used for testing only
        else
          raise ArgumentError, "wrong number of arguments (#{args.length} for 1)"
        end
      end

      def perform
        @logger.info("Processing update release")
        @event_log.begin_stage("Updating release", 3)

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
            release_tgz = File.join(@tmp_release_dir, ReleaseManager::RELEASE_TGZ)
            tar_output = `tar -C #{@tmp_release_dir} -xzf #{release_tgz} 2>&1`
            raise ReleaseInvalidArchive.new($?.exitstatus, tar_output) if $?.exitstatus != 0
          ensure
            FileUtils.rm(release_tgz) if File.exists?(release_tgz)
          end
        end
      end

      def verify_manifest
        track_and_log("Verifying manifest") do
          manifest_file = File.join(@tmp_release_dir, "release.MF")
          raise ReleaseManifestNotFound unless File.file?(manifest_file)

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
          @release_version_entry = Models::ReleaseVersion.new(:release => @release, :version => @release_version)
          raise ReleaseAlreadyExists unless @release_version_entry.valid?
          @release_version_entry.save
        end

        resolve_package_dependencies(@release_manifest["packages"])

        @packages = {}
        process_packages

        process_jobs
      end

      def normalize_manifest
        ["name", "version"].each do |property|
          @release_manifest[property] = @release_manifest[property].to_s
        end

        @release_manifest["packages"].each do |package_meta|
          ["name", "version", "sha1"].each { |property| package_meta[property] = package_meta[property].to_s }
        end

        @release_manifest["jobs"].each do |job_meta|
          ["name", "version", "sha1"].each { |property| job_meta[property] = job_meta[property].to_s }
        end
      end

      def resolve_package_dependencies(packages)
        packages_by_name = {}
        packages.each do |package|
          packages_by_name[package["name"]] = package
          package["dependencies"] ||= []
        end
        dependency_lookup = lambda { |package_name| packages_by_name[package_name]["dependencies"] }
        result = CycleHelper.check_for_cycle(packages_by_name.keys, :connected_vertices=> true, &dependency_lookup)
        packages.each do |package|
          @logger.info("Resolving package dependencies for: #{package["name"]}, " +
                           "found: #{package["dependencies"].pretty_inspect}")
          package["dependencies"] = result[:connected_vertices][package["name"]]
          @logger.info("Resolved package dependencies for: #{package["name"]}, " +
                           "to: #{package["dependencies"].pretty_inspect}")
        end
      end

      def process_packages
        @logger.info("Checking for new packages in release")

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
            existing_packages << [ package, package_meta ]
          end
        end

        if new_packages.size > 0
          @event_log.begin_stage("Creating new packages", new_packages.size)
          new_packages.each do |package_meta|
            package_desc = "#{package_meta["name"]}/#{package_meta["version"]}"
            @event_log.track(package_desc) do
              @logger.info("Creating new package `#{package_desc}'")
              package = create_package(package_meta)
              register_package(package)
            end
          end
        end

        if existing_packages.size > 0
          n_packages = existing_packages.size
          @event_log.begin_stage("Processing #{n_packages} existing package#{n_packages > 1 ? "s" : ""}", 1)
          @event_log.track("Verifying checksums") do
            existing_packages.each do |package, package_meta|
              package_desc = "#{package.name}/#{package.version}"
              @logger.info("Package `#{package_desc}' already exists, verifying checksum")
              # TODO: make sure package dependencies have not changed
              raise ReleaseExistingPackageHashMismatch if package.sha1 != package_meta["sha1"]
              @logger.info("Package `#{package_desc}' verified")
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
        @logger.info("Checking for new jobs in release")

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
            existing_jobs << [ template, job_meta ]
          end
        end

        if new_jobs.size > 0
          @event_log.begin_stage("Creating new jobs", new_jobs.size)
          new_jobs.each do |job_meta|
            job_desc = "#{job_meta["name"]}/#{job_meta["version"]}"
            @event_log.track(job_desc) do
              @logger.info("Creating new template #{job_desc}")
              template = create_job(job_meta)
              register_template(template)
            end
          end
        end

        if existing_jobs.size > 0
          n_jobs = existing_jobs.size
          @event_log.begin_stage("Processing #{n_jobs} existing job#{n_jobs > 1 ? "s" : ""}", 1)
          @event_log.track("Verifying checksums") do
            existing_jobs.each do |template, job_meta|
              job_desc = "#{template.name}/#{template.version} (#{job_meta["sha1"]})"
              @logger.info("Job `#{job_desc}' already exists, verifying checksum")
              raise ReleaseExistingJobHashMismatch if template.sha1 != job_meta["sha1"]
              @logger.info("Job `#{job_desc}' verified")
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

        @logger.info("Creating package: #{package.name}")

        package_tgz = File.join(@tmp_release_dir, "packages", "#{package.name}.tgz")
        output = `tar -tzf #{package_tgz} 2>&1`
        raise PackageInvalidArchive.new($?.exitstatus, output) if $?.exitstatus != 0

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

        @logger.info("Processing job: #{template.name}")
        job_tgz = File.join(@tmp_release_dir, "jobs", "#{template.name}.tgz")
        job_dir = File.join(@tmp_release_dir, "jobs", "#{template.name}")

        FileUtils.mkdir_p(job_dir)

        output = `tar -C #{job_dir} -xzf #{job_tgz} 2>&1`

        raise JobInvalidArchive.new(template.name, $?.exitstatus, output) if $?.exitstatus != 0

        manifest_file = File.join(job_dir, "job.MF")
        raise JobMissingManifest.new(template.name) unless File.file?(manifest_file)

        job_manifest = YAML.load_file(manifest_file)

        if job_manifest["templates"]
          job_manifest["templates"].each_key do |relative_path|
            path = File.join(job_dir, "templates", relative_path)
            raise JobMissingTemplateFile.new(template.name, relative_path) unless File.file?(path)
          end
        end

        unless File.exists?(File.join(job_dir, "monit")) || Dir.glob(File.join(job_dir, "*.monit")).size > 0
          raise JobMissingMonit.new(template.name)
        end

        # TODO: verify sha1
        File.open(job_tgz) do |f|
          template.blobstore_id = @blobstore.create(f)
        end

        package_names = []
        job_manifest["packages"].each do |package_name|
          package = @packages[package_name]
          raise JobMissingPackage.new(job_meta["name"], package_name) if package.nil?
          package_names << package.name
        end
        template.package_names = package_names

        if job_manifest["logs"]
          raise JobInvalidLogSpec.new(template.name) unless job_manifest["logs"].is_a?(Hash)
          template.logs = job_manifest["logs"]
        end

        template.save
      end

    end
  end
end
