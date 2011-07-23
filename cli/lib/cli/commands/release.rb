module Bosh::Cli::Command
  class Release < Base
    include Bosh::Cli::DependencyHelper
    include Bosh::Cli::VersionCalc

    def verify(tarball_path, *options)
      tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)

      say("\nVerifying release...")
      tarball.validate
      nl

      if tarball.valid?
        say("'%s' is a valid release" % [ tarball_path] )
      else
        say("'%s' is not a valid release:" % [ tarball_path] )
        for error in tarball.errors
          say("- %s" % [ error ])
        end
      end
    end

    def upload(release_file = nil)
      auth_required

      if release_file.nil?
        check_if_release_dir
        release_file = Bosh::Cli::Release.dev(work_dir).latest_release_filename
        if release_file.nil?
          err("The information about latest generated release is missing, please provide release filename")
        end
        unless non_interactive? || ask("Are you sure you want to upload release `#{release_file.green}'? (type 'yes' to continue)") == 'yes'
          err("Canceled upload")
        end
      end

      file_type = `file --mime-type -b '#{release_file}'`

      if file_type =~ /text\/(plain|yaml)/
        upload_manifest(release_file)
      else # Just assume tarball
        upload_tarball(release_file)
      end
    end

    def upload_manifest(manifest_path)
      manifest       = load_yaml_file(manifest_path)
      remote_release = get_remote_release(manifest["name"]) rescue nil
      blobstore      = init_blobstore(Bosh::Cli::Release.final(work_dir).s3_options)
      tmpdir         = Dir.mktmpdir

      at_exit { FileUtils.rm_rf(tmpdir) }

      release = Bosh::Cli::ReleaseCompiler.new(manifest_path, blobstore, remote_release)
      need_repack = true

      unless release.exists?
        release.tarball_path = File.join(tmpdir, "release.tgz")
        release.compile
        need_repack = false
      end
      upload_tarball(release.tarball_path, :repack => need_repack)
    end

    def upload_tarball(tarball_path, options = {})
      tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)
      # Trying to repack release by default
      repack  = options.has_key?(:repack) ? !!options[:repack] : true

      say("\nVerifying release...")
      tarball.validate(:allow_sparse => true)
      nl

      if !tarball.valid?
        err("Release is invalid, please fix, verify and upload again")
      end

      begin
        remote_release = get_remote_release(tarball.release_name)
        if remote_release["versions"].include?(tarball.version)
          err "This release version has already been uploaded"
        end

        if repack
          say "Checking if can repack release for faster upload..."
          repacked_path = tarball.repack(remote_release)
          if repacked_path.nil?
            say "Uploading the whole release".green
          else
            say "Release repacked (new size is #{pretty_size(repacked_path)})".green
            tarball_path = repacked_path
          end
        end
      rescue Bosh::Cli::DirectorError
        say "Cannot get this release information from director, possibly a new release"
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
      check_if_release_dir
      if options.size == 1 && File.file?(options[0])
        create_from_manifest(options[0])
        release_filename = options[0]
      else
        release_filename = create_from_spec(*options)
      end

      if release_filename
        dev_release = Bosh::Cli::Release.dev(work_dir)
        dev_release.update_config(:latest_release_filename => release_filename)
      end
    end

    def create_from_manifest(manifest_file)
      say "Recreating release from the manifest"
      final_release = Bosh::Cli::Release.final(work_dir)
      blobstore     = init_blobstore(final_release.s3_options)

      Bosh::Cli::ReleaseCompiler.compile(manifest_file, blobstore)
    end

    def create_from_spec(*options)
      final         = options.include?("--final")
      force         = options.include?("--force")
      manifest_only = !options.include?("--with-tarball")
      dry_run       = options.include?("--dry-run")

      check_if_dirty_state unless force

      packages  = []
      jobs      = []

      final_release = Bosh::Cli::Release.final(work_dir)
      dev_release   = Bosh::Cli::Release.dev(work_dir)

      if final
        header "Building FINAL release".green
        release = final_release
      else
        header "Building DEV release".green
        release = dev_release
      end

      if version_greater(release.min_cli_version, Bosh::Cli::VERSION)
        err("You should use CLI >= %s with this release, you have %s" % [ release.min_cli_version, Bosh::Cli::VERSION ])
      end

      if release.name.blank?
        name = ask("Please enter %s release name: " % [ final ? "final" : "development" ])
        err("Canceled release creation, no name given") if name.blank?
        release.update_config(:name => name)
      end

      blobstore = init_blobstore(final_release.s3_options)

      header "Building packages"
      Dir[File.join(work_dir, "packages", "*", "spec")].each do |package_spec|
        package = Bosh::Cli::PackageBuilder.new(package_spec, work_dir, final, blobstore)
        package.dry_run = dry_run
        say "Building #{package.name.green}..."
        package.build
        packages << package
        nl
      end

      if packages.size > 0
        sorted_packages = tsort_packages(packages.inject({}) { |h, p| h[p.name] = p.dependencies; h })
        header "Resolving dependencies"
        say "Dependencies resolved, correct build order is:"
        for package_name in sorted_packages
          say("- %s" % [ package_name ])
        end
        nl
      end

      built_package_names = packages.map { |package| package.name }

      header "Building jobs"
      Dir[File.join(work_dir, "jobs", "*")].each do |job_dir|
        prepare_script = File.join(job_dir, "prepare")
        job_spec = File.join(job_dir, "spec")

        if File.exists?(prepare_script)
          say "Found prepare script in `#{File.basename(job_dir)}'"
          Bosh::Cli::JobBuilder.run_prepare_script(prepare_script)
        end

        job = Bosh::Cli::JobBuilder.new(job_spec, work_dir, final, blobstore, built_package_names)
        job.dry_run = dry_run
        say "Building #{job.name.green}..."
        job.build
        jobs << job
        nl
      end

      builder = Bosh::Cli::ReleaseBuilder.new(work_dir, packages, jobs, :final => final)

      unless dry_run
        if manifest_only
          builder.build(:generate_tarball => false)
        else
          builder.build(:generate_tarball => true)
          say("Built release #{builder.version} at '#{builder.tarball_path.green}'")
          say("Release size: #{pretty_size(builder.tarball_path).green}")
        end
      end

      header "Release summary"
      show_summary(builder)
      nl

      return nil if dry_run

      say("Release manifest saved in '#{builder.manifest_path.green}'")
      [dev_release, final_release].each do |release|
        release.update_config(:min_cli_version => Bosh::Cli::VERSION)
      end

      builder.manifest_path
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
      releases = director.list_releases.sort { |r1, r2| r1["name"] <=> r2["name"] }

      err("No releases") if releases.size == 0

      releases_table = table do |t|
        t.headings = "Name", "Versions"
        releases.each do |r|
          t << [ r["name"], r["versions"].sort { |v1, v2| version_cmp(v1, v2) }.join(", ") ]
        end
      end

      nl
      say(releases_table)
      nl
      say("Releases total: %d" % releases.size)
    end

    def delete(name, *options)
      auth_required
      force = options.include?("--force")
      options.delete("--force")
      version = options.shift

      desc = "release `#{name}'"
      desc << " version #{version}" if version

      if force
        say "Deleting #{desc} (FORCED DELETE, WILL IGNORE ERRORS)".red
      elsif options.size > 0
        err "Unknown option, currently only '--force' is supported"
      else
        say "Deleting #{desc}".red
      end

      if operation_confirmed?
        status, body = director.delete_release(name, :force => force, :version => version)
        responses = {
          :done          => "Deleted #{desc}",
          :non_trackable => "Started deleting release but director at '#{target}' doesn't support deployment tracking",
          :track_timeout => "Started deleting release but timed out out while tracking status",
          :error         => "Started deleting release but received an error while tracking status",
        }

        say responses[status] || "Cannot delete release: #{body}"
      else
        say "Canceled deleting release".green
      end
    end

    private

    def show_summary(builder)
      packages_table = table do |t|
        t.headings = %w(Name Version Notes Fingerprint)
        builder.packages.each do |package|
          t << artefact_summary(package)
        end
      end

      jobs_table = table do |t|
        t.headings = %w(Name Version Notes Fingerprint)
        builder.jobs.each do |job|
          t << artefact_summary(job)
        end
      end

      say "Packages"
      say packages_table
      nl
      say "Jobs"
      say jobs_table
    end

    def artefact_summary(artefact)
      result = [ ]
      result << artefact.name
      result << artefact.version
      result << artefact.notes.join(", ")
      result << artefact.fingerprint
      result
    end

    def get_remote_release(name)
      release = director.get_release(name)

      unless release.is_a?(Hash) && release.has_key?("jobs") && release.has_key?("packages")
        raise Bosh::Cli::DirectorError, "Cannot find version, jobs and packages info in the director response, maybe old director?"
      end

      release
    end
  end
end
