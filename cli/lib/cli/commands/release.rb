module Bosh::Cli::Command
  class Release < Base
    include Bosh::Cli::DependencyHelper
    include Bosh::Cli::YamlHelper

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

    def upload(release_file)
      auth_required
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
      if options.size == 1 && File.file?(options[0])
        create_from_manifest(options[0])
      else
        create_from_spec(*options)
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

      check_if_release_dir
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

      if version_cmp(Bosh::Cli::VERSION, release.min_cli_version) < 0
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
      Dir[File.join(work_dir, "jobs", "*", "spec")].each do |job_spec|
        job = Bosh::Cli::JobBuilder.new(job_spec, work_dir, final, blobstore, built_package_names)
        say "Building #{job.name.green}..."
        job.build
        jobs << job
        nl
      end

      builder = Bosh::Cli::ReleaseBuilder.new(work_dir, packages, jobs, :final => final)

      if manifest_only
        builder.build(:generate_tarball => false)
      else
        builder.build(:generate_tarball => true)
        say("Built release #{builder.version} at '#{builder.tarball_path.green}'")
        say("Release size: #{pretty_size(builder.tarball_path).green}")
      end

      say("Release manifest saved in '#{builder.manifest_path.green}'")
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

      nl
      say(releases_table)
      nl
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

    def get_remote_release(name)
      release = director.get_release(name)

      unless release.is_a?(Hash) && release.has_key?("jobs") && release.has_key?("packages")
        raise Bosh::Cli::DirectorError, "Cannot find version, jobs and packages info in the director response, maybe old director?"
      end

      release
    end
  end
end
