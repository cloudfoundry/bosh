# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Release < Base
    DEFAULT_RELEASE_NAME = "bosh-release"

    include Bosh::Cli::DependencyHelper
    include Bosh::Cli::VersionCalc

    # bosh init release
    usage "init release"
    desc "Initialize release directory"
    option "--git", "initialize git repository"
    def init(base = nil)
      if base
        FileUtils.mkdir_p(base)
        Dir.chdir(base)
      end

      err("Release already initialized") if in_release_dir?
      git_init if options[:git]

      %w[config jobs packages src blobs].each do |dir|
        FileUtils.mkdir(dir)
      end

      # Initialize an empty blobs index
      File.open(File.join("config", "blobs.yml"), "w") do |f|
        YAML.dump({}, f)
      end

      say("Release directory initialized".green)
    end

    # bosh create release
    usage "create release"
    desc "Create release (assumes current directory " +
         "to be a release repository)"
    option "--force", "bypass git dirty state check"
    option "--final", "create final release"
    option "--with-tarball", "create release tarball"
    option "--dry-run", "stop before writing release manifest"
    def create(manifest_file = nil)
      check_if_release_dir

      if manifest_file && File.file?(manifest_file)
        release_filename = create_from_manifest(manifest_file)
      else
        release_filename = create_from_spec
      end

      if release_filename
        release.latest_release_filename = release_filename
        release.save_config
      end
    end

    # bosh verify release
    usage "verify release"
    desc "Verify release"
    def verify(tarball_path)
      tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)

      nl
      say("Verifying release...")
      tarball.validate
      nl

      if tarball.valid?
        say("`#{tarball_path}' is a valid release".green)
      else
        say("Validation errors:".red)
        tarball.errors.each do |error|
          say("- #{error}")
        end
        err("`#{tarball_path}' is not a valid release".red)
      end
    end

    usage "upload release"
    desc "Upload release"
    option "--rebase",
           "Rebases this release onto the latest version",
           "known by director (discards local job/package",
           "versions in favor of versions assigned by director)"
    def upload(release_file = nil)
      auth_required

      upload_options = {
        :rebase => options[:rebase],
        :repack => true
      }

      if release_file.nil?
        check_if_release_dir
        release_file = release.latest_release_filename
        if release_file.nil?
          err("The information about latest generated release is missing, " +
              "please provide release filename")
        end
        unless confirmed?("Upload release " +
                          "`#{File.basename(release_file).green}' " +
                          "to `#{target_name.green}'")
          err("Canceled upload")
        end
      end

      unless File.exist?(release_file)
        err("Release file doesn't exist")
      end

      file_type = `file --mime-type -b '#{release_file}'`

      if file_type =~ /text\/(plain|yaml)/
        upload_manifest(release_file, upload_options)
      else
        upload_tarball(release_file, upload_options)
      end
    end

    usage "reset release"
    desc "Reset dev release"
    def reset
      check_if_release_dir

      say("Your dev release environment will be completely reset".red)
      if confirmed?
        say("Removing dev_builds index...")
        FileUtils.rm_rf(".dev_builds")
        say("Clearing dev name...")
        release.dev_name = nil
        release.save_config
        say("Removing dev tarballs...")
        FileUtils.rm_rf("dev_releases")

        say("Release has been reset".green)
      else
        say("Canceled")
      end
    end

    usage "releases"
    desc "Show the list of available releases"
    def list
      auth_required
      releases = director.list_releases.sort do |r1, r2|
        r1["name"] <=> r2["name"]
      end

      err("No releases") if releases.empty?

      releases_table = table do |t|
        t.headings = "Name", "Versions"
        releases.each do |r|
          versions = r["versions"].sort { |v1, v2|
            version_cmp(v1, v2)
          }.map { |v| ((r["in_use"] || []).include?(v)) ? "#{v}*" : v }

          t << [r["name"], versions.join(", ")]
        end
      end

      nl
      say(releases_table)
      say("(*) Currently deployed") if releases_table.to_s =~ /\*/
      nl
      say("Releases total: %d" % releases.size)
    end

    usage "delete release"
    desc "Delete release (or a particular release version)"
    option "--force", "ignore errors during deletion"
    def delete(name, version = nil)
      auth_required
      force = !!options[:force]

      desc = "#{name}"
      desc << "/#{version}" if version

      if force
        say("Deleting `#{desc}' (FORCED DELETE, WILL IGNORE ERRORS)".red)
      else
        say("Deleting `#{desc}'".red)
      end

      if confirmed?
        status, task_id = director.delete_release(
          name, :force => force, :version => version)
        task_report(status, task_id, "Deleted `#{desc}'")
      else
        say("Canceled deleting release".green)
      end
    end

    protected

    def upload_manifest(manifest_path, upload_options = {})
      package_matches = match_remote_packages(File.read(manifest_path))

      find_release_dir(manifest_path)

      blobstore = release.blobstore
      tmpdir = Dir.mktmpdir

      compiler = Bosh::Cli::ReleaseCompiler.new(
        manifest_path, blobstore, package_matches)
      need_repack = true

      unless compiler.exists?
        compiler.tarball_path = File.join(tmpdir, "release.tgz")
        compiler.compile
        need_repack = false
      end

      upload_options[:repack] = need_repack
      upload_tarball(compiler.tarball_path, upload_options)
    end

    def upload_tarball(tarball_path, upload_options = {})
      tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)
      # Trying to repack release by default
      repack = upload_options[:repack]
      rebase = upload_options[:rebase]

      say("\nVerifying release...")
      tarball.validate(:allow_sparse => true)
      nl

      unless tarball.valid?
        err("Release is invalid, please fix, verify and upload again")
      end

      begin
        remote_release = get_remote_release(tarball.release_name) rescue nil

        if remote_release && !rebase &&
          remote_release["versions"].include?(tarball.version)
          err("This release version has already been uploaded")
        end

        if repack
          package_matches = match_remote_packages(tarball.manifest)

          say("Checking if can repack release for faster upload...")
          repacked_path = tarball.repack(package_matches)
          if repacked_path.nil?
            say("Uploading the whole release".green)
          else
            say("Release repacked " +
                "(new size is #{pretty_size(repacked_path)})".green)
            tarball_path = repacked_path
          end
        end
      rescue Bosh::Cli::DirectorError
        # It's OK for director to choke on getting
        # a release info (think new releases)
      end

      if rebase
        say("Uploading release (#{"will be rebased".yellow})")
        status, task_id = director.rebase_release(tarball_path)
        task_report(status, task_id, "Release rebased")
      else
        say("\nUploading release\n")
        status, task_id = director.upload_release(tarball_path)
        task_report(status, task_id, "Release uploaded")
      end
    end

    def create_from_manifest(manifest_file)
      say("Recreating release from the manifest")
      Bosh::Cli::ReleaseCompiler.compile(manifest_file, release.blobstore)
      manifest_file
    end

    def create_from_spec
      final = options[:final]
      force = options[:force]
      manifest_only = !options[:with_tarball]
      dry_run = options[:dry_run]

      if final && !release.has_blobstore_secret?
        err("Can't create final release without blobstore secret")
      end

      blob_manager.sync
      if blob_manager.dirty?
        blob_manager.print_status
        if force
          say("Proceeding with dirty blobs as '--force' is given".red)
        else
          err("Please use '--force' or upload new blobs")
        end
      end

      check_if_dirty_state unless force

      confirmation = "Are you sure you want to " +
        "generate #{'final'.red} version? "

      if final && !dry_run && !confirmed?(confirmation)
        say("Canceled release generation".green)
        exit(1)
      end

      if final
        header("Building FINAL release".green)
        release_name = release.final_name
      else
        release_name = release.dev_name
        header("Building DEV release".green)
      end

      if version_greater(release.min_cli_version, Bosh::Cli::VERSION)
        err("You should use CLI >= #{release.min_cli_version} " +
              "with this release, you have #{Bosh::Cli::VERSION}")
      end

      if release_name.blank?
        confirmation = "Please enter %s release name: " % [
          final ? "final" : "development"]
        name = interactive? ? ask(confirmation).to_s : DEFAULT_RELEASE_NAME
        err("Canceled release creation, no name given") if name.blank?
        if final
          release.final_name = name
        else
          release.dev_name = name
        end
        release.save_config
      end

      header("Building packages")

      packages = Bosh::Cli::PackageBuilder.discover(
        work_dir,
        :final => final,
        :blobstore => release.blobstore,
        :dry_run => dry_run
      )

      packages.each do |package|
        say("Building #{package.name.green}...")
        package.build
        nl
      end

      if packages.size > 0
        package_index = packages.inject({}) do |index, package|
          index[package.name] = package.dependencies
          index
        end
        sorted_packages = tsort_packages(package_index)
        header("Resolving dependencies")
        say("Dependencies resolved, correct build order is:")
        sorted_packages.each do |package_name|
          say("- %s" % [package_name])
        end
        nl
      end

      built_package_names = packages.map { |package| package.name }

      header("Building jobs")
      jobs = Bosh::Cli::JobBuilder.discover(
        work_dir,
        :final => final,
        :blobstore => release.blobstore,
        :dry_run => dry_run,
        :package_names => built_package_names
      )

      jobs.each do |job|
        say("Building #{job.name.green}...")
        job.build
        nl
      end

      builder = Bosh::Cli::ReleaseBuilder.new(release, packages,
                                              jobs, :final => final)

      unless dry_run
        if manifest_only
          builder.build(:generate_tarball => false)
        else
          builder.build(:generate_tarball => true)
        end
      end

      header("Release summary")
      show_summary(builder)
      nl

      return nil if dry_run

      say("Release version: #{builder.version.to_s.green}")
      say("Release manifest: #{builder.manifest_path.green}")

      unless manifest_only
        say("Release tarball (#{pretty_size(builder.tarball_path)}): " +
              builder.tarball_path.green)
      end

      release.min_cli_version = Bosh::Cli::VERSION
      release.save_config

      builder.manifest_path
    end

    def git_init
      out = %x{git init 2>&1}
      if $? != 0
        say("error running 'git init':\n#{out}")
      else
        File.open(".gitignore", "w") do |f|
          f << <<-EOS.gsub(/^\s{10}/, '')
          config/dev.yml
          config/private.yml
          releases/*.tgz
          dev_releases
          .blobs
          blobs
          .dev_builds
          .idea
          .DS_Store
          .final_builds/jobs/**/*.tgz
          .final_builds/packages/**/*.tgz
          *.swp
          *~
          *#
          #*
          EOS
        end
      end
    rescue Errno::ENOENT
      say("Unable to run 'git init'".red)
    end

    private

    # if we aren't already in a release directory, try going up two levels
    # to see if that is a release directory, and then use that as the base
    def find_release_dir(manifest_path)
      unless in_release_dir?
        dir = File.expand_path("../..", manifest_path)
        Dir.chdir(dir)
        if in_release_dir?
          @release = Bosh::Cli::Release.new(dir)
        end
      end

    end

    def show_summary(builder)
      packages_table = table do |t|
        t.headings = %w(Name Version Notes)
        builder.packages.each do |package|
          t << artefact_summary(package)
        end
      end

      jobs_table = table do |t|
        t.headings = %w(Name Version Notes)
        builder.jobs.each do |job|
          t << artefact_summary(job)
        end
      end

      say("Packages")
      say(packages_table)
      nl
      say("Jobs")
      say(jobs_table)

      affected_jobs = builder.affected_jobs

      if affected_jobs.size > 0
        nl
        say("Jobs affected by changes in this release")

        affected_jobs_table = table do |t|
          t.headings = %w(Name Version)
          affected_jobs.each do |job|
            t << [job.name, job.version]
          end
        end

        say(affected_jobs_table)
      end
    end

    def artefact_summary(artefact)
      result = []
      result << artefact.name
      result << artefact.version
      result << artefact.notes.join(", ")
      result
    end

    def get_remote_release(name)
      release = director.get_release(name)

      unless release.is_a?(Hash) &&
          release.has_key?("jobs") &&
          release.has_key?("packages")
        raise Bosh::Cli::DirectorError,
              "Cannot find version, jobs and packages info " +
              "in the director response, maybe old director?"
      end

      release
    end

    def match_remote_packages(manifest_yaml)
      director.match_packages(manifest_yaml)
    rescue Bosh::Cli::DirectorError
      msg = "You are using CLI >= 0.20 with director that doesn't support " +
        "package matches.\nThis will result in uploading all packages " +
        "and jobs to your director.\nIt is recommended to update your " +
        "director or downgrade your CLI to 0.19.6"

      say(msg.yellow)
      exit(1) unless confirmed?
    end
  end
end