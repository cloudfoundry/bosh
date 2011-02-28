module Bosh::Director
  module Jobs
    class UpdateRelease
      extend BaseJob

      @queue = :normal

      def initialize(*args)
        if args.length == 1
          release_dir = args.first
          @tmp_release_dir = release_dir
          @blobstore = Config.blobstore
          @logger = Config.logger
        elsif args.empty?
          # used for testing only
        else
          raise ArgumentError, "wrong number of arguments (#{args.length} for 1)"
        end
      end

      def perform
        @logger.info("Processing update release")

        @release_tgz = File.join(@tmp_release_dir, ReleaseManager::RELEASE_TGZ)
        extract_release

        @release_manifest_file = File.join(@tmp_release_dir, "release.MF")
        verify_manifest

        release_lock = Lock.new("lock:release:#{@release_name}")
        release_lock.lock do
          @release = Models::Release.find_or_create(:name => @release_name)
          process_release
        end
        "/releases/#{@release_name}/#{@release_version}"
      rescue Exception => e
        # cleanup
        if @release_version_entry && !@release_version_entry.new?
          @release_version_entry.destroy if @release_version_entry
        end
        raise e
      ensure
        FileUtils.rm_rf(@tmp_release_dir)
        # TODO: delete task status file or cleanup later?
      end

      def process_release
        @release_version_entry = Models::ReleaseVersion.new(:release => @release, :version => @release_version)
        raise ReleaseAlreadyExists unless @release_version_entry.valid?
        @release_version_entry.save

        resolve_package_dependencies(@release_manifest["packages"])

        @packages = {}
        @release_manifest["packages"].each do |package_meta|
          @logger.info("Checking if package: #{package_meta["name"]}:#{package_meta["version"]} already " +
                           "exists in release #{@release.pretty_inspect}")
          package = Models::Package[:release_id => @release.id,
                                    :name => package_meta["name"],
                                    :version => package_meta["version"]]
          if package.nil?
            @logger.info("Creating new package")
            package = create_package(package_meta)
          else
            @logger.info("Package already exists: #{package.pretty_inspect}, verifying that it's the same")
            # TODO: make sure package dependencies have not changed
            raise ReleaseExistingPackageHashMismatch if package.sha1 != package_meta["sha1"]
            @logger.info("Package verified")
          end
          @packages[package_meta["name"]] = package
          @release_version_entry.add_package(package)
        end

        @release_manifest["jobs"].each do |job_meta|
          @logger.info("Checking if job: #{job_meta["name"]}:#{job_meta["version"]} already " +
                           "exists in release #{@release.pretty_inspect}")
          template = Models::Template[:release_id => @release.id,
                                      :name => job_meta["name"],
                                      :version => job_meta["version"]]
          if template.nil?
            @logger.info("Creating new template")
            template = create_job(job_meta)
          else
            @logger.info("Template already exists: #{template.pretty_inspect}, verifying that it's the same")
            raise ReleaseExistingJobHashMismatch if template.sha1 != job_meta["sha1"]
            @logger.info("Template verified")
          end
          @release_version_entry.add_template(template)
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

      def extract_release
        @logger.info("Extracting release")

        output = `tar -C #{@tmp_release_dir} -xzf #{@release_tgz} 2>&1`
        raise ReleaseInvalidArchive.new($?.exitstatus, output) if $?.exitstatus != 0
        FileUtils.rm(@release_tgz)
      end

      def verify_manifest
        @logger.info("Verifying manifest")

        raise ReleaseManifestNotFound unless File.file?(@release_manifest_file)
        @release_manifest = YAML.load_file(@release_manifest_file)

        normalize_manifest

        @release_name = @release_manifest["name"]
        @release_version = @release_manifest["version"]

        # TODO: make sure all jobs are there
        # TODO: make sure there are no extra jobs

        # TODO: make sure all packages are there
        # TODO: make sure there are no extra packages
      end

      def normalize_manifest
        ["name", "version"].each { |property| @release_manifest[property] = @release_manifest[property].to_s }
        @release_manifest["packages"].each do |package_meta|
          ["name", "version", "sha1"].each { |property| package_meta[property] = package_meta[property].to_s }
        end

        @release_manifest["jobs"].each do |job_meta|
          ["name", "version", "sha1"].each { |property| job_meta[property] = job_meta[property].to_s }
        end
      end

      def create_package(package_meta)
        package = Models::Package.new(:release => @release,
                                      :name => package_meta["name"],
                                      :version => package_meta["version"],
                                      :sha1 => package_meta["sha1"])
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
        template = Models::Template.new(:release => @release,
                                        :name => job_meta["name"],
                                        :version => job_meta["version"],
                                        :sha1 => job_meta["sha1"])

        @logger.info("Processing job: #{template.name}")
        job_tgz = File.join(@tmp_release_dir, "jobs", "#{template.name}.tgz")
        job_dir = File.join(@tmp_release_dir, "jobs", "#{template.name}")

        FileUtils.mkdir_p(job_dir)

        output = `tar -C #{job_dir} -xzf #{job_tgz} 2>&1`
        raise JobInvalidArchive.new(name, $?.exitstatus, output) if $?.exitstatus != 0

        manifest_file = File.join(job_dir, "job.MF")
        raise JobMissingManifest.new(name) unless File.file?(manifest_file)

        job_manifest = YAML.load_file(manifest_file)

        if job_manifest["templates"]
          job_manifest["templates"].each_key do |relative_path|
            path = File.join(job_dir, "templates", relative_path)
            raise JobMissingTemplateFile.new(name, relative_path) unless File.file?(path)
          end
        end

        raise JobMissingMonit.new(name) unless File.file?(File.join(job_dir, "monit"))

        # TODO: verify sha1
        File.open(job_tgz) do |f|
          template.blobstore_id = @blobstore.create(f)
        end

        package_names = []
        job_manifest["packages"].each do |package_name|
          package = @packages[package_name]
          raise JobMissingPackage.new(name, package_name) if package.nil?
          package_names << package.name
        end
        template.package_names = package_names

        template.save
      end

    end
  end
end
