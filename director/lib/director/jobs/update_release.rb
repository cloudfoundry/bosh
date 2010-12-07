module Bosh::Director

  module Jobs

    class UpdateRelease

      @queue = :normal

      def self.perform(task_id, release_dir)
        UpdateRelease.new(task_id, release_dir).perform
      end

      def initialize(task_id, release_dir)
        @task = Models::Task[task_id]
        raise TaskNotFound if @task.nil?

        @tmp_release_dir = release_dir
        @blobstore = Config.blobstore

        task_status_file = File.join(Config.base_dir, "tasks", task_id.to_s)
        FileUtils.mkdir_p(File.dirname(task_status_file))
        @logger = Logger.new(task_status_file)
        @logger.level= Config.logger.level
        Config.logger = @logger

        @task.output = task_status_file
        @task.save!
      end

      def perform
        @task.state = :processing
        @task.timestamp = Time.now.to_i
        @task.save!

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
              @release.save!
            end

            @release_version_entry = Models::ReleaseVersion.new(:release => @release, :version => @release_version)
            raise ReleaseAlreadyExists unless @release_version_entry.valid?
            @release_version_entry.save!

            @packages = {}
            @release_manifest["packages"].each do |package_meta|
              package = Models::Package.find(:release_id => @release.id, :name => package_meta["name"],
                                             :version => package_meta["version"])[0]
              if package.nil?
                package = create_package(package_meta)
              else
                raise ReleaseExistingPackageHashMismatch if package.sha1 != package_meta["sha1"]
              end
              @packages[package_meta["name"]] = package
            end

            @release_manifest["jobs"].each do |job_name|
              create_job(job_name)
            end

            @task.state = :done
            @task.result = "/releases/#{@release_name}/#{@release_version}"
            @task.timestamp = Time.now.to_i
            @task.save!
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

      def extract_release
        @task.events << [Time.now.to_i, :extracting].join(":")

        `tar -C #{@tmp_release_dir} -xzf #{@release_tgz}`
        raise ReleaseInvalidArchive if $?.exitstatus != 0
        FileUtils.rm(@release_tgz)
      end

      def verify_manifest
        @task.events << [Time.now.to_i, :verifying].join(":")

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

        @task.events << [Time.now.to_i, "creating package: #{package.name}"].join(":")

        package_tgz = File.join(@tmp_release_dir, "packages", "#{package.name}.tgz")
        `tar -tzf #{package_tgz}`
        raise PackageInvalid.new(:invalid_archive) if $?.exitstatus != 0

        File.open(package_tgz) do |f|
          package.blobstore_id = @blobstore.create(f)
        end

        package.save!
        package
      end

      def create_job(name)
        @task.events << [Time.now.to_i, "processing job: #{name}"].join(":")
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
