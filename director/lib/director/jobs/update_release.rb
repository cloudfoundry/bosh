module Bosh::Director

  module Jobs

    class UpdateRelease

      @queue = :normal

      def self.perform(task_id, release_dir)
        UpdateRelease.new(task_id, release_dir).perform
      end

      def initialize(task_id, release_dir)
        @task = Models::Task[task_id]
        raise TaskInvalid if @task.nil?

        @tmp_release_dir = release_dir

        @task_status_file = File.join(Config.base_dir, "tasks", task_id.to_s)
        FileUtils.mkdir_p(File.dirname(@task_status_file))
      end

      def perform
        @task.state = :processing
        @task.timestamp = Time.now.to_i
        @task.output = @task_status_file
        @task.save

        begin
          @release_tgz = File.join(@tmp_release_dir, ReleaseManager::RELEASE_TGZ)
          extract_release

          @release_manifest_file = File.join(@tmp_release_dir, "release.MF")
          verify_manifest

          release_lock = Lock.new("lock:release:#{@release_name}")
          release_lock.lock do
            @release = Models::Release.find(:name => @release_name)[0]
            if @release.nil?
              @release = Models::Release.new(:name => @release_name)
              @release.create
            end

            @release_version_entry = Models::ReleaseVersion.new(:release => @release, :version => @release_version)
            raise ReleaseBundleInvalid, :release_already_exists unless @release_version_entry.valid?
            @release_version_entry.create

            @package_versions = {}
            @release_manifest["packages"].each do |package_meta|
              package = Models::Package.find(:release_id => @release.id, :name => package_meta["name"],
                                             :version => package_meta["version"])[0]
              if package.nil?
                create_package(package_meta)
              else
                raise ReleaseBundleInvalid.new(:existing_package_sha1_mismatch) if package.sha1 != package_meta["sha1"]
              end
              @package_versions[package_meta["name"]] = package_meta["version"]
            end

            create_package_symlinks

            @release_manifest["jobs"].each do |job_name|
              save_job(job_name)
            end

            @task.state = :done
            @task.result = "/releases/#{@release_name}/#{@release_version}"
            @task.timestamp = Time.now.to_i
            @task.save
          end
        rescue => e
          @release.delete if @release && !@release.new?
          FileUtils.rm_rf(@release_version_dir) if @release_version_dir

          @task.state = :error
          @task.result = e.to_s
          @task.timestamp = Time.now.to_i
          @task.save
          
          raise e
        ensure
          FileUtils.rm_rf(@tmp_release_dir)

          # TODO: delete task status file or cleanup later?
        end
      end

      def extract_release
        @task.events << [Time.now.to_i, :extracting].join(":")

        `tar -C #{@tmp_release_dir} -xzf #{@release_tgz}`
        raise ReleaseBundleInvalid.new(:invalid_archive) if $?.exitstatus != 0
        FileUtils.rm(@release_tgz)
      end

      def verify_manifest
        @task.events << [Time.now.to_i, :verifying].join(":")

        raise ReleaseBundleInvalid.new(:release_manifest_not_found) unless File.file?(@release_manifest_file)
        @release_manifest = YAML.load_file(@release_manifest_file)

        @release_name = @release_manifest["name"]
        @release_version = @release_manifest["version"]
        @release_dir = File.join(Config.base_dir, "releases", @release_name)
        @release_version_dir = File.join(@release_dir, "versions", @release_version.to_s)

        # TODO: make sure all jobs are there
        # TODO: make sure there are no extra jobs

        # TODO: make sure all packages are there
        # TODO: make sure there are no extra packages
      end

      def create_package(package_meta)
        package = Models::Package.new(:release => @release, :name => package_meta["name"],
                                      :version => package_meta["version"], :sha1 => package_meta["sha1"])
        package_dir = File.join(@release_dir, "packages", package.name)
        package_versioned_dir = File.join(package_dir, package.version.to_s)
        package_versioned_tgz = File.join(package_dir, "#{package.version}.tgz")

        @task.events << [Time.now.to_i, "creating package: #{package.name}"].join(":")

        FileUtils.mkdir_p(package_versioned_dir)

        package_tgz = File.join(@tmp_release_dir, "packages", "#{package.name}.tgz")
        `tar -C #{package_versioned_dir} -xzf #{package_tgz}`
        raise PackageInvalid.new(:invalid_archive) if $?.exitstatus != 0

        @task.events << [Time.now.to_i, "compiling package: #{package.name}"].join(":")
        compile_package(package_versioned_dir)

        package_contents_dir = File.join(package_versioned_dir, "contents")
        Dir.chdir(package_contents_dir)
        `tar -czf #{package_versioned_tgz} *`
        raise PackageInvalid.new(:could_not_archive_package) if $?.exitstatus != 0

        FileUtils.rm_rf(package_versioned_dir)
        raise PackageInvalid.new(:error_creating_package) unless @release.valid?
        package.create
      end

      def compile_package(package_dir)
        Dir.chdir(package_dir)
        `./compile >> #{@task_status_file} 2>&1`
        raise PackageInvalid.new(:compilation_failed) if $?.exitstatus != 0
      end


      def create_package_symlinks
        dest_packages_dir = File.join(@release_version_dir, "packages")
        FileUtils.mkdir_p(dest_packages_dir)
        @release_manifest["packages"].each do |package|
          package_name = package["name"]
          package_version = package["version"]
          src_package = File.join(@release_dir, "packages", package_name, "#{package_version}.tgz")
          dest_package = File.join(dest_packages_dir, "#{package_name}.tgz")
          FileUtils.ln_s(src_package, dest_package)
        end
      end

      def save_job(name)
        @task.events << [Time.now.to_i, "processing job: #{name}"].join(":")
        job_dir = File.join(@release_version_dir, "jobs", name)
        job_tgz = File.join(@tmp_release_dir, "jobs", "#{name}.tgz")

        FileUtils.mkdir_p(job_dir)

        `tar -C #{job_dir} -xzf #{job_tgz}`
        raise JobInvalid.new(:invalid_archive) if $?.exitstatus != 0

        manifest_file = File.join(job_dir, "job.MF")
        raise JobInvalid.new(:missing_manifest) unless File.file?(manifest_file)

        job_manifest = YAML.load_file(manifest_file)
        job_manifest["configuration"].each_key do |file|
          file = File.join(job_dir, "config", file)
          raise JobInvalid.new(:missing_config_file) unless File.file?(file)
        end

        job_manifest["packages"].each do |package|
          unless File.symlink?(File.join(@release_version_dir, "packages", "#{package}.tgz"))
            raise JobInvalid.new(:missing_package)
          end
        end

        raise JobInvalid.new(:missing_monit_file) unless File.file?(File.join(job_dir, "monit"))

        job_manifest["packages"].each do |package_name|
          package = Models::Package.find(:release_id => @release.id, :name => package_name,
                                         :version => @package_versions[package_name])[0]
          raise JobInvalid.new(:missing_package) if package.nil?
        end
        
      end

    end
  end
end
