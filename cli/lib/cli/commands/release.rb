module Bosh::Cli::Command
  class Release < Base
    include Bosh::Cli::DependencyHelper

    def verify(tarball_path)
      release = Bosh::Cli::ReleaseUploader.new(tarball_path)

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
      auth_required

      release = Bosh::Cli::ReleaseUploader.new(tarball_path)

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
      check_if_release_dir

      packages  = []
      jobs      = []
      final     = flags.to_s =~ /^\s*--final\s*$/i

      if final
        header "Building FINAL release".green
        release = Bosh::Cli::Release.final(work_dir)
      else
        header "Building DEV release".green
        release = Bosh::Cli::Release.dev(work_dir)
      end

      if release.name.blank?
        name = ask("Please enter %s release name: " % [ final ? "final" : "development" ])
        err("Canceled release creation, no name given") if name.blank?
        release.update_config(:name => name)
      end

      blobstore = init_blobstore(release.s3_options)

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
        job = Bosh::Cli::JobBuilder.new(job_spec, work_dir, final, blobstore, built_package_names)
        say "Building #{job.name}..."
        job.build
        jobs << job
      end

      builder = Bosh::Cli::ReleaseBuilder.new(work_dir, packages, jobs, final)
      builder.build

      say("Built release #{builder.version} at '#{builder.tarball_path}'")
    end

    def reset
      check_if_release_dir

      release = Bosh::Cli::Release.dev(work_dir)

      say "Your dev release environment will be completely reset".red
      if (non_interactive? || ask("Are you sure? (type 'yes' to continue): ") == "yes")
        say "Removing dev_builds index..."
        FileUtils.rm_rf(".dev_builds")
        say "Clearing dev name and version..."
        release.update_config(:name => nil, :version => nil)
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

      if (non_interactive? || ask("Are you sure? (type 'yes' to continue): ") == "yes")
        director.delete_release(name, :force => force)
      else
        say "Canceled deleting release".green
      end
    end

  end
end
