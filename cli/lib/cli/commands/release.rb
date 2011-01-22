module Bosh::Cli::Command
  class Release < Base
    include Bosh::Cli::DependencyHelper

    def verify(tarball_path)
      release = Bosh::Cli::Release.new(tarball_path)

      say("\nVerifying release...")
      release.validate
      say("\n")

      if release.valid?
        say("'%s' is a valid release" % [ tarball_path] )
      else
        say("'%s' is not a valid release:" % [ tarball_path] )
        for error in release.errors
          say("- %s" % [ error ])
        end
      end      
    end

    def upload(tarball_path)
      err("Please log in first") unless logged_in?
      err("Please choose target") unless target
      
      release = Bosh::Cli::Release.new(tarball_path)

      say("\nVerifying release...")
      release.validate
      say("\n")

      if !release.valid?
        err("Release is invalid, please fix, verify and upload again")
      end

      say("\nUploading release...\n")

      status, message = director.upload_release(tarball_path)

      responses = {
        :done          => "Release uploaded and updated",
        :non_trackable => "Uploaded release but director at #{target} doesn't support update tracking",
        :track_timeout => "Uploaded release but timed out out while tracking status",
        :error         => "Uploaded release but received an error while tracking status"
      }

      say responses[status] || "Cannot upload release: #{message}"
    end

    def create(flags = "")
      packages  = []
      jobs      = []
      final     = flags.to_s =~ /\s*--final\s*/i

      if !in_release_dir?
        err "Sorry, your current directory doesn't look like release directory"
      end

      if final
        header "Building FINAL release".green
      else
        header "Building DEV release".green
      end

      blobstore = init_blobstore

      header "Building packages"
      Dir[File.join(work_dir, "packages", "*", "spec")].each do |package_spec|

        package = Bosh::Cli::PackageBuilder.new(package_spec, work_dir, final, blobstore)
        say "Building #{package.name}..."
        package.build

        packages << package
      end

      if packages.size > 0
        sorted_packages = tsort_packages(packages.inject({}) { |h, p| h[p.name] = p.dependencies; h })
        header "Resolving dependencies"
        say "Dependencies resolved, correct build order is:"
        for package_name in sorted_packages
          say("- %s" % [ package_name ])
        end
      end

      built_package_names = packages.map { |package| package.name }

      header "Building jobs"
      Dir[File.join(work_dir, "jobs", "*", "spec")].each do |job_spec|
        job = Bosh::Cli::JobBuilder.new(job_spec, work_dir, built_package_names)
        say "Building #{job.name}..."
        job.build
        jobs << job
      end

      release = Bosh::Cli::ReleaseBuilder.new(work_dir, packages, jobs, final)
      release.build

      say("Built release #{release.version} at '#{release.tarball_path}'")
    end

    def list
      err("Please log in first") unless logged_in?
      err("Please choose target") unless target
      releases = director.list_releases

      err("No releases") if releases.size == 0

      releases_table = table do |t|
        t.headings = "Name", "Versions"
        releases.each do |r|
          t << [ r["name"], r["versions"].join(", ") ]
        end
      end

      say("\n")
      say(releases_table)
      say("\n")
      say("Releases total: %d" % releases.size)
    end

    private

    def in_release_dir?
      File.directory?("packages") && File.directory?("jobs") && File.directory?("src")
    end

    def init_blobstore
      storage_config = File.join(@work_dir, "storage.yml")

      if !File.file?(storage_config)
        raise Bosh::Cli::ConfigError, "No storage config file found at `#{storage_config}'"
      end

      storage_options = YAML.load_file(storage_config)
      storage_options = { } unless storage_options.is_a?(Hash)

      bs_options = {
        :access_key_id     => storage_options["access_key_id"].to_s,
        :secret_access_key => storage_options["secret_access_key"].to_s,
        :encryption_key    => storage_options["encryption_key"].to_s,
        :bucket_name       => storage_options["bucket_name"].to_s
      }

      Bosh::Blobstore::Client.create("s3", bs_options)
    rescue Bosh::Blobstore::BlobstoreError => e
      err "Cannot init blobstore: #{e}"
    end

  end
end
