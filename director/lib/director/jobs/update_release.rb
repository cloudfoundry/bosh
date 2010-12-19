module Bosh::Director

  module Jobs

    class UpdateRelease

      @queue = :normal

      def self.perform(task_id, release_dir)
        UpdateRelease.new(task_id, release_dir).perform
      end

      def initialize(*args)
        if args.length == 2
          task_id, release_dir = args
          @task = Models::Task[task_id]
          raise TaskNotFound if @task.nil?

          @logger = Logger.new(@task.output)
          @logger.level = Config.logger.level
          @logger.formatter = ThreadFormatter.new
          @logger.info("Starting task: #{task_id}")
          Config.logger = @logger

          begin
            @tmp_release_dir = release_dir
            @blobstore = Config.blobstore
          rescue Exception => e
            @logger.error("#{e} - #{e.backtrace.join("\n")}")
            @task.state = :error
            @task.result = e.to_s
            @task.timestamp = Time.now.to_i
            @task.save!
            raise e
          end
        elsif args.empty?
          # used for testing only
        else
          raise ArgumentError, "wrong number of arguments (#{args.length} for 2)"
        end
      end

      def perform
        @task.state = :processing
        @task.timestamp = Time.now.to_i
        @task.save!

        @logger.info("Processing update release")

        begin
          @release_tgz = File.join(@tmp_release_dir, ReleaseManager::RELEASE_TGZ)
          extract_release

          @release_manifest_file = File.join(@tmp_release_dir, "release.MF")
          verify_manifest

          release_lock = Lock.new("lock:release:#{@release_name}")
          release_lock.lock do
            find_release
            process_release

            @task.state = :done
            @task.result = "/releases/#{@release_name}/#{@release_version}"
            @task.timestamp = Time.now.to_i
            @task.save!
            @logger.info("Done")
          end
        rescue Exception => e
          @logger.error("#{e} - #{e.backtrace.join("\n")}")

          templates = Models::Template.find(:release_version => @release_version_entry)
          templates.each {|template| template.delete}

          @release_version_entry.delete if @release_version_entry && !@release_version_entry.new?

          @task.state = :error
          @task.result = e.to_s
          @task.timestamp = Time.now.to_i
          @task.save!

          raise e
        ensure
          FileUtils.rm_rf(@tmp_release_dir)
          # TODO: delete task status file or cleanup later?
        end
      end

      def find_release
        @logger.info("Looking up release: #{@release_name}")
        @release = Models::Release.find(:name => @release_name).first
        if @release.nil?
          @logger.info("Release \"#{@release_name}\" did not exist, creating")
          @release = Models::Release.new(:name => @release_name)
          @release.save!
        end
      end

      def process_release
        @release_version_entry = Models::ReleaseVersion.new(:release => @release, :version => @release_version)
        raise ReleaseAlreadyExists unless @release_version_entry.valid?
        @release_version_entry.save!

        resolve_package_dependencies(@release_manifest["packages"])

        @packages = {}
        @release_manifest["packages"].each do |package_meta|
          package = Models::Package.find(:release_id => @release.id, :name => package_meta["name"],
                                         :version => package_meta["version"])[0]
          if package.nil?
            package = create_package(package_meta)
          else
            # TODO: make sure package dependencies have not changed
            raise ReleaseExistingPackageHashMismatch if package.sha1 != package_meta["sha1"]
          end
          @packages[package_meta["name"]] = package
        end

        @release_manifest["jobs"].each do |job_name|
          create_job(job_name)
        end
      end

      def resolve_package_dependencies(packages)
        packages_by_name = {}
        packages.each do |package|
          packages_by_name[package["name"]] = package
          package["dependencies"] ||= []
        end
        dependency_lookup = lambda {|package_name| packages_by_name[package_name]["dependencies"]}
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

        @release_name = @release_manifest["name"]
        @release_version = @release_manifest["version"]

        # TODO: make sure all jobs are there
        # TODO: make sure there are no extra jobs

        # TODO: make sure all packages are there
        # TODO: make sure there are no extra packages
      end

      def create_package(package_meta)
        package = Models::Package.new(:release => @release, :name => package_meta["name"],
                                      :version => package_meta["version"], :sha1 => package_meta["sha1"])

        @logger.info("Creating package: #{package.name}")

        package_tgz = File.join(@tmp_release_dir, "packages", "#{package.name}.tgz")
        output = `tar -tzf #{package_tgz} 2>&1`
        raise PackageInvalidArchive.new($?.exitstatus, output) if $?.exitstatus != 0

        File.open(package_tgz) do |f|
          package.blobstore_id = @blobstore.create(f)
        end

        package.save!

        dependencies = package.dependencies
        package_meta["dependencies"].each {|dependency| dependencies << dependency}

        package
      end

      def create_job(name)
        @logger.info("Processing job: #{name}")
        job_tgz = File.join(@tmp_release_dir, "jobs", "#{name}.tgz")
        job_dir = File.join(@tmp_release_dir, "jobs", "#{name}")

        FileUtils.mkdir_p(job_dir)

        `tar -C #{job_dir} -xzf #{job_tgz}`
        raise JobInvalid.new(:invalid_archive) if $?.exitstatus != 0

        manifest_file = File.join(job_dir, "job.MF")
        raise JobInvalid.new(:missing_manifest) unless File.file?(manifest_file)

        job_manifest = YAML.load_file(manifest_file)

        if job_manifest["configuration"]
          job_manifest["configuration"].each_key do |file|
            file = File.join(job_dir, "config", file)
            raise JobInvalid.new(:missing_config_file) unless File.file?(file)
          end
        end

        template = Models::Template.new(:release_version => @release_version_entry, :name => name)
        template.save!

        job_manifest["packages"].each do |package_name|
          package = @packages[package_name]
          raise JobInvalid.new(:missing_package) if package.nil?
          template.packages << package
        end

        raise JobInvalid.new(:missing_monit_file) unless File.file?(File.join(job_dir, "monit"))

        File.open(job_tgz) do |f|
          template.blobstore_id = @blobstore.create(f)
        end
        template.save!

      end

    end
  end
end
