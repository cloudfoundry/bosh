module Bosh::Cli::Command
  class Release < Base
    include Bosh::Cli::DependencyHelper

    def verify(tarball_path, *options)
      tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)

      say("\nVerifying release...")
      tarball.validate
      say("\n")

      if tarball.valid?
        say("'%s' is a valid release" % [ tarball_path] )
      else
        say("'%s' is not a valid release:" % [ tarball_path] )
        for error in tarball.errors
          say("- %s" % [ error ])
        end
      end
    end

    def upload(tarball_path)
      auth_required

      tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)

      say("\nVerifying release...")
      tarball.validate(:allow_sparse => true)
      say("\n")

      if !tarball.valid?
        err("Release is invalid, please fix, verify and upload again")
      end

      begin
        release_info = fetch_release_info(tarball.release_name)

        if release_info["versions"].include?(tarball.version)
          err "This release version has already been uploaded"
        end

        say "Checking if we can repack release and perform sparse upload"

        jobs_to_remove = []
        packages_to_remove = []

        tarball.jobs.each do |local_job|
          job = release_info["jobs"].detect do |remote_job|
            local_job["name"] == remote_job["name"] && local_job["version"].to_s == remote_job["version"].to_s
          end
          desc = "`#{local_job["name"]} (#{local_job["version"]})'"

          if job
            if job["sha1"] == local_job["sha1"]
              jobs_to_remove << local_job["name"]
              say "Job #{desc} already exists, no need to upload".green
            else
              err "Job #{desc} has a different checksum remotely, please fix release"
            end
          else
            say "Job #{desc} needs to be uploaded".red
          end
        end

        tarball.packages.each do |local_package|
          package = release_info["packages"].detect do |remote_package|
            local_package["name"] == remote_package["name"] && local_package["version"].to_s == remote_package["version"].to_s
          end
          desc = "`#{local_package["name"]} (#{local_package["version"]})'"

          if package
            if package["sha1"] == local_package["sha1"]
              packages_to_remove << local_package["name"]
              say "Package #{desc} already exists, no need to upload".green
            else
              err "Package #{desc} has a different checksum remotely, please fix release"
            end
          else
            say "Package #{desc} needs to be uploaded".red
          end
        end

        if packages_to_remove.size > 0 || jobs_to_remove.size > 0
          say "Repacking release for sparse upload...".green
          repacked_path = tarball.repack(packages_to_remove, jobs_to_remove)
          if repacked_path.nil?
            say "Failed to repack".red
          else
            tarball_path = repacked_path
          end
        end

      rescue Bosh::Cli::DirectorError => e
        say e.message
        say "Need to upload the whole release"
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

    def create(*options)
      final  = options.include?("--final")
      force  = options.include?("--force")
      sparse = options.include?("--sparse")

      if final && sparse
        err "Final sparse releases are not allowed"
      end

      check_if_release_dir
      check_if_dirty_state unless force

      packages  = []
      jobs      = []

      packages_to_skip = []
      jobs_to_skip     = []

      final_release = Bosh::Cli::Release.final(work_dir)
      dev_release = Bosh::Cli::Release.dev(work_dir)

      if final
        header "Building FINAL release".green
        release = final_release
      else
        header "Building DEV release".green
        release = dev_release
      end

      if version_cmp(Bosh::Cli::VERSION, release.min_cli_version) < 0
        err("You should use CLI >= %s with this release, you have %s" % [ release.min_cli_version, Bosh::Cli::VERSION ])
      end

      if release.name.blank?
        name = ask("Please enter %s release name: " % [ final ? "final" : "development" ])
        err("Canceled release creation, no name given") if name.blank?
        release.update_config(:name => name)
      end

      if sparse
        begin
          say "Fetching existing release from director to allow sparse release creation...".green
          release_info = fetch_release_info(release.name)
        rescue Bosh::Cli::DirectorError => e
          say e.message
          say "Creating full release"
          sparse = false
        end
      end

      blobstore = init_blobstore(final_release.s3_options)

      header "Building packages"
      Dir[File.join(work_dir, "packages", "*", "spec")].each do |package_spec|

        package = Bosh::Cli::PackageBuilder.new(package_spec, work_dir, final, blobstore)
        header "Building #{package.name.green}..."
        package.build

        packages << package

        if sparse
          remote_package = release_info["packages"].detect do |rp|
            package.name == rp["name"] && package.version.to_s == rp["version"].to_s
          end

          desc = "`#{package.name} (#{package.version})'"

          if remote_package
            packages_to_skip << package
            say "Package #{desc} already exists".green
          else
            say "Package #{desc} will be included into release".red
          end
        end
        say("\n")
      end

      if packages.size > 0
        sorted_packages = tsort_packages(packages.inject({}) { |h, p| h[p.name] = p.dependencies; h })
        header "Resolving dependencies"
        say "Dependencies resolved, correct build order is:"
        for package_name in sorted_packages
          say("- %s" % [ package_name ])
        end
        say("\n")
      end

      built_package_names = packages.map { |package| package.name }

      header "Building jobs"
      Dir[File.join(work_dir, "jobs", "*", "spec")].each do |job_spec|
        job = Bosh::Cli::JobBuilder.new(job_spec, work_dir, final, blobstore, built_package_names)
        say "Building #{job.name.green}..."
        job.build
        jobs << job

        if sparse
          remote_job = release_info["jobs"].detect do |rj|
            job.name == rj["name"] && job.version.to_s == rj["version"].to_s
          end

          desc = "`#{job.name} (#{job.version})'"

          if remote_job
            jobs_to_skip << job
            say "Job #{desc} already exists".green
          else
            say "Job #{desc} will be included into release".red
          end
        end
        say("\n")
      end

      builder = Bosh::Cli::ReleaseBuilder.new(work_dir, packages, jobs, packages_to_skip, jobs_to_skip, :final => final)
      builder.build

      say("Built release #{builder.version} at '#{builder.tarball_path}'")
      if sparse
        say("Please note that this release is sparse and probably is only useful with your current target director".red)
      end
    end

    def reset
      check_if_release_dir

      release = Bosh::Cli::Release.dev(work_dir)

      say "Your dev release environment will be completely reset".red
      if (non_interactive? || ask("Are you sure? (type 'yes' to continue): ") == "yes")
        say "Removing dev_builds index..."
        FileUtils.rm_rf(".dev_builds")
        say "Clearing dev name and version..."
        release.update_config(:name => nil)
        say "Removing dev tarballs..."
        FileUtils.rm_rf("dev_releases")

        say "Release has been reset".green
      else
        say "Canceled"
      end
    end

    def list
      auth_required
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

    def delete(name, *options)
      auth_required
      force = false

      if options.include?("--force")
        force = true
        say "Deleting release `#{name}' (FORCED DELETE, WILL IGNORE ERRORS)".red
      elsif options.size > 0
        err "Unknown option, currently only '--force' is supported"
      else
        say "Deleting release `#{name}'".red
      end

      if operation_confirmed?
        director.delete_release(name, :force => force)
      else
        say "Canceled deleting release".green
      end
    end

    private

    def version_cmp(v1, v2)
      major1, minor1, patch1 = v1.to_s.split(".", 3).map { |v| v.to_i }
      major2, minor2, patch2 = v2.to_s.split(".", 3).map { |v| v.to_i }

      result = major1.to_i <=> major2.to_i
      result = minor1.to_i <=> minor2.to_i if result == 0
      result = patch1.to_i <=> patch2.to_i if result == 0
      result
    end

    def fetch_release_info(name)
      release_info = director.get_release(name)

      unless release_info.is_a?(Hash) && release_info.has_key?("jobs") && release_info.has_key?("packages")
        raise Bosh::Cli::DirectorError, "Cannot find version, jobs and packages info in the director response, maybe old director?"
      end

      release_info
    end

  end
end
