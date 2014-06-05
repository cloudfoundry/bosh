module Bosh::Cli::Command
  class Release < Base
    DEFAULT_RELEASE_NAME = 'bosh-release'

    include Bosh::Cli::DependencyHelper

    # bosh init release
    usage 'init release'
    desc 'Initialize release directory'
    option '--git', 'initialize git repository'
    def init(base = nil)
      if base
        FileUtils.mkdir_p(base)
        Dir.chdir(base)
      end

      err('Release already initialized') if in_release_dir?
      git_init if options[:git]

      %w[config jobs packages src blobs].each do |dir|
        FileUtils.mkdir(dir)
      end

      # Initialize an empty blobs index
      File.open(File.join('config', 'blobs.yml'), 'w') do |f|
        Psych.dump({}, f)
      end

      say('Release directory initialized'.make_green)
    end

    # bosh create release
    usage 'create release'
    desc 'Create release (assumes current directory to be a release repository)'
    option '--force', 'bypass git dirty state check'
    option '--final', 'create final release'
    option '--with-tarball', 'create release tarball'
    option '--dry-run', 'stop before writing release manifest'
    option '--version VERSION', 'specify a custom version number (ex: 1.0.0 or 1.0-beta.2+dev.10)'
    def create(manifest_file = nil)
      check_if_release_dir

      if manifest_file && File.file?(manifest_file)
        if options[:version]
          err('Cannot specify a custom version number when creating from a manifest. The manifest already specifies a version.'.make_red)
        end

        say('Recreating release from the manifest')
        Bosh::Cli::ReleaseCompiler.compile(manifest_file, release.blobstore)
        release_filename = manifest_file
      else
        version = options[:version]
        version = Bosh::Common::Version::ReleaseVersion.parse(version).to_s unless version.nil?

        release_filename = create_from_spec(version)
      end

      if release_filename
        release.latest_release_filename = release_filename
        release.save_config
      end
    rescue SemiSemantic::ParseError
      err("Invalid version: `#{version}'. Please specify a valid version (ex: 1.0.0 or 1.0-beta.2+dev.10).".make_red)
    rescue Bosh::Cli::ReleaseVersionError => e
      err(e.message.make_red)
    end

    # bosh verify release
    usage 'verify release'
    desc 'Verify release'
    def verify(tarball_path)
      tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)

      nl
      say('Verifying release...')
      tarball.validate
      nl

      if tarball.valid?
        say("`#{tarball_path}' is a valid release".make_green)
      else
        say('Validation errors:'.make_red)
        tarball.errors.each do |error|
          say("- #{error}")
        end
        err("`#{tarball_path}' is not a valid release".make_red)
      end
    end

    usage 'upload release'
    desc 'Upload release (release_file can be a local file or a remote URI)'
    option '--rebase',
      'Rebases this release onto the latest version',
      'known by director (discards local job/package',
      'versions in favor of versions assigned by director)'
    option '--skip-if-exists', 'skips upload if release already exists'
    def upload(release_file = nil)
      auth_required

      upload_options = {
        :rebase => options[:rebase],
        :repack => true,
        :skip_if_exists => options[:skip_if_exists],
      }

      if release_file.nil?
        check_if_release_dir
        release_file = release.latest_release_filename
        if release_file.nil?
          err('The information about latest generated release is missing, please provide release filename')
        end
        unless confirmed?("Upload release `#{File.basename(release_file).make_green}' to `#{target_name.make_green}'")
          err('Canceled upload')
        end
      end

      if release_file =~ /^#{URI::regexp}$/
        upload_remote_release(release_file, upload_options)
      else
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
    end

    usage 'reset release'
    desc 'Reset dev release'
    def reset
      check_if_release_dir

      say('Your dev release environment will be completely reset'.make_red)
      if confirmed?
        say('Removing dev_builds index...')
        FileUtils.rm_rf('.dev_builds')
        say('Clearing dev name...')
        release.dev_name = nil
        release.save_config
        say('Removing dev tarballs...')
        FileUtils.rm_rf('dev_releases')

        say('Release has been reset'.make_green)
      else
        say('Canceled')
      end
    end

    usage 'releases'
    desc 'Show the list of available releases'
    option '--jobs', 'include job templates'
    def list
      auth_required
      releases = director.list_releases.sort do |r1, r2|
        r1['name'] <=> r2['name']
      end

      err('No releases') if releases.empty?

      currently_deployed = false
      uncommited_changes = false
      if releases.first.has_key? 'release_versions'
        releases_table = build_releases_table(releases, options)
        currently_deployed, uncommited_changes = release_version_details(releases)
      elsif releases.first.has_key? 'versions'
        releases_table = build_releases_table_for_old_director(releases)
        currently_deployed, uncommited_changes = release_version_details_for_old_director(releases)
      end

      nl
      say(releases_table.render)

      say('(*) Currently deployed') if currently_deployed
      say('(+) Uncommitted changes') if uncommited_changes
      nl
      say('Releases total: %d' % releases.size)
    end

    usage 'delete release'
    desc 'Delete release (or a particular release version)'
    option '--force', 'ignore errors during deletion'
    def delete(name, version = nil)
      auth_required
      force = !!options[:force]

      desc = "#{name}"
      desc << "/#{version}" if version

      if force
        say("Deleting `#{desc}' (FORCED DELETE, WILL IGNORE ERRORS)".make_red)
      else
        say("Deleting `#{desc}'".make_red)
      end

      if confirmed?
        status, task_id = director.delete_release(name, force: force, version: version)
        task_report(status, task_id, "Deleted `#{desc}'")
      else
        say('Canceled deleting release'.make_green)
      end
    end

    private

    def upload_manifest(manifest_path, upload_options = {})
      package_matches = match_remote_packages(File.read(manifest_path))

      find_release_dir(manifest_path)

      blobstore = release.blobstore
      tmpdir = Dir.mktmpdir

      compiler = Bosh::Cli::ReleaseCompiler.new(manifest_path, blobstore, package_matches)
      need_repack = true

      unless compiler.exists?
        compiler.tarball_path = File.join(tmpdir, 'release.tgz')
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
        err('Release is invalid, please fix, verify and upload again')
      end

      if should_convert_to_old_format?(tarball.version)
        msg = "You are using CLI > 1.2579.0 with a director that doesn't support" +
          'the new version format you are using. Upgrade your ' +
          'director to match the version of your CLI or downgrade your ' +
          'CLI to 1.2579.0 to avoid versioning mismatch issues.'

        say(msg.make_yellow)
        tarball_path = tarball.convert_to_old_format
      end

      remote_release = get_remote_release(tarball.release_name) rescue nil
      if remote_release && !rebase
        if remote_release['versions'].include?(tarball.version)
          if upload_options[:skip_if_exists]
            say("Release `#{tarball.release_name}/#{tarball.version}' already exists. Skipping upload.")
            return
          else
            err('This release version has already been uploaded')
          end
        end
      end

      begin
        if repack
          package_matches = match_remote_packages(tarball.manifest)

          say('Checking if can repack release for faster upload...')
          repacked_path = tarball.repack(package_matches)

          if repacked_path.nil?
            say('Uploading the whole release'.make_green)
          else
            say("Release repacked (new size is #{pretty_size(repacked_path)})".make_green)
            tarball_path = repacked_path
          end
        end
      rescue Bosh::Cli::DirectorError
        # It's OK for director to choke on getting
        # a release info (think new releases)
      end

      if rebase
        say("Uploading release (#{'will be rebased'.make_yellow})")
        status, task_id = director.rebase_release(tarball_path)
        task_report(status, task_id, 'Release rebased')
      else
        say("\nUploading release\n")
        status, task_id = director.upload_release(tarball_path)
        task_report(status, task_id, 'Release uploaded')
      end
    end

    def upload_remote_release(release_location, upload_options = {})
      nl
      if upload_options[:rebase]
        say("Using remote release `#{release_location}' (#{'will be rebased'.make_yellow})")
        status, task_id = director.rebase_remote_release(release_location)
        task_report(status, task_id, 'Release rebased')
      else
        say("Using remote release `#{release_location}'")
        status, task_id = director.upload_remote_release(release_location)
        task_report(status, task_id, 'Release uploaded')
      end
    end

    def create_from_spec(version)
      final = options[:final]
      force = options[:force]
      manifest_only = !options[:with_tarball]
      dry_run = options[:dry_run]

      err("Can't create final release without blobstore secret") if final && !release.has_blobstore_secret?

      dirty_blob_check(force)

      raise_dirty_state_error if dirty_state? && !force

      if final
        confirm_final_release(dry_run)
        save_final_release_name if release.final_name.blank?
        header('Building FINAL release'.make_green)
      else
        save_dev_release_name if release.dev_name.blank?
        header('Building DEV release'.make_green)
      end

      header('Building packages')
      packages = build_packages(dry_run, final)

      header('Building jobs')
      jobs = build_jobs(packages.map(&:name), dry_run, final)

      header('Building release')
      release_builder = build_release(dry_run, final, jobs, manifest_only, packages, version)

      header('Release summary')
      show_summary(release_builder)
      nl

      return nil if dry_run

      say("Release version: #{release_builder.version.to_s.make_green}")
      say("Release manifest: #{release_builder.manifest_path.make_green}")

      unless manifest_only
        say("Release tarball (#{pretty_size(release_builder.tarball_path)}): " +
                release_builder.tarball_path.make_green)
      end

      release.save_config

      release_builder.manifest_path
    end

    def confirm_final_release(dry_run)
      confirmed = non_interactive? || agree("Are you sure you want to generate #{'final'.make_red} version? ")
      if !dry_run && !confirmed
        say('Canceled release generation'.make_green)
        exit(1)
      end
    end

    def dirty_blob_check(force)
      blob_manager.sync
      if blob_manager.dirty?
        blob_manager.print_status
        if force
          say("Proceeding with dirty blobs as '--force' is given".make_red)
        else
          err("Please use '--force' or upload new blobs")
        end
      end
    end

    def build_packages(dry_run, final)
      packages = Bosh::Cli::PackageBuilder.discover(
          work_dir,
          :final => final,
          :blobstore => release.blobstore,
          :dry_run => dry_run
      )

      packages.each do |package|
        say("Building #{package.name.make_green}...")
        package.build
        nl
      end

      if packages.size > 0
        package_index = packages.inject({}) do |index, package|
          index[package.name] = package.dependencies
          index
        end
        sorted_packages = tsort_packages(package_index)
        header('Resolving dependencies')
        say('Dependencies resolved, correct build order is:')
        sorted_packages.each do |package_name|
          say('- %s' % [package_name])
        end
        nl
      end

      packages
    end

    def build_release(dry_run, final, jobs, manifest_only, packages, version)
      release_builder = Bosh::Cli::ReleaseBuilder.new(release, packages, jobs, final: final,
                                                      commit_hash: commit_hash, version: version,
                                                      uncommitted_changes: dirty_state?)

      unless dry_run
        if manifest_only
          release_builder.build(:generate_tarball => false)
        else
          release_builder.build(:generate_tarball => true)
        end
      end

      release_builder
    end

    def build_jobs(built_package_names, dry_run, final)
      jobs = Bosh::Cli::JobBuilder.discover(
          work_dir,
          :final => final,
          :blobstore => release.blobstore,
          :dry_run => dry_run,
          :package_names => built_package_names
      )

      jobs.each do |job|
        say("Building #{job.name.make_green}...")
        job.build
        nl
      end

      jobs
    end

    def save_final_release_name
      release.final_name = DEFAULT_RELEASE_NAME
      if interactive?
        release.final_name = ask('Please enter final release name: ').to_s
        err('Canceled release creation, no name given') if release.final_name.blank?
      end
      release.save_config
    end

    def save_dev_release_name
      if interactive?
        release.dev_name = ask('Please enter development release name: ') do |q|
          q.default = release.final_name if release.final_name
        end.to_s
        err('Canceled release creation, no name given') if release.dev_name.blank?
      else
        release.dev_name = release.final_name ? release.final_name : DEFAULT_RELEASE_NAME
      end
      release.save_config
    end

    def git_init
      out = %x{git init 2>&1}
      if $? != 0
        say("error running 'git init':\n#{out}")
      else
        File.open('.gitignore', 'w') do |f|
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
      say("Unable to run 'git init'".make_red)
    end

    # if we aren't already in a release directory, try going up two levels
    # to see if that is a release directory, and then use that as the base
    def find_release_dir(manifest_path)
      unless in_release_dir?
        dir = File.expand_path('../..', manifest_path)
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

      say('Packages')
      say(packages_table)
      nl
      say('Jobs')
      say(jobs_table)

      affected_jobs = builder.affected_jobs

      if affected_jobs.size > 0
        nl
        say('Jobs affected by changes in this release')

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
      result << artefact.notes.join(', ')
      result
    end

    def get_remote_release(name)
      release = director.get_release(name)

      unless release.is_a?(Hash) &&
          release.has_key?('jobs') &&
          release.has_key?('packages')
        raise Bosh::Cli::DirectorError,
          'Cannot find version, jobs and packages info in the director response, maybe old director?'
      end

      release
    end

    def match_remote_packages(manifest_yaml)
      director.match_packages(manifest_yaml)
    rescue Bosh::Cli::DirectorError
      msg = "You are using CLI >= 0.20 with director that doesn't support " +
          "package matches.\nThis will result in uploading all packages " +
          "and jobs to your director.\nIt is recommended to update your " +
        'director or downgrade your CLI to 0.19.6'

      say(msg.make_yellow)
      exit(1) unless confirmed?
    end

    def build_releases_table_for_old_director(releases)
      table do |t|
        t.headings = 'Name', 'Versions'
        releases.each do |release|
          versions = release['versions'].sort { |v1, v2|
            Bosh::Common::Version::ReleaseVersion.parse_and_compare(v1, v2)
          }.map { |v| ((release['in_use'] || []).include?(v)) ? "#{v}*" : v }

          t << [release['name'], versions.join(', ')]
        end
      end
    end

    # Builds table of release information
    # Default headings: "Name", "Versions", "Commit Hash"
    # Extra headings: options[:job] => "Jobs"
    def build_releases_table(releases, options = {})
      show_jobs = options[:jobs]
      table do |t|
        t.headings = 'Name', 'Versions', 'Commit Hash'
        t.headings << 'Jobs' if show_jobs
        releases.each do |release|
          versions, commit_hashes = formatted_versions(release).transpose
          row = [release['name'], versions.join("\n"), commit_hashes.join("\n")]
          if show_jobs
            jobs = formatted_jobs(release).transpose
            row << jobs.join("\n")
          end
          t << row
        end
      end
    end

    def formatted_versions(release)
      sort_versions(release['release_versions']).map { |v| formatted_version_and_commit_hash(v) }
    end

    def sort_versions(versions)
      versions.sort { |v1, v2| Bosh::Common::Version::ReleaseVersion.parse_and_compare(v1['version'], v2['version']) }
    end

    def formatted_version_and_commit_hash(version)
      version_number = version['version'] + (version['currently_deployed'] ? '*' : '')
      commit_hash = version['commit_hash'] + (version['uncommitted_changes'] ? '+' : '')
      [version_number, commit_hash]
    end

    def formatted_jobs(release)
      sort_versions(release['release_versions']).map do |v|
        if job_names = v['job_names']
          [job_names.join(', ')]
        else
          ['n/a  '] # with enough whitespace to match "Jobs" header
        end
      end
    end

    def commit_hash
      status = Bosh::Exec.sh('git show-ref --head --hash=8 2> /dev/null')
      status.output.split.first
    rescue Bosh::Exec::Error => e
      '00000000'
    end

    def release_version_details(releases)
      currently_deployed = false
      uncommitted_changes = false
      releases.each do |release|
        release['release_versions'].each do |version|
          currently_deployed ||= version['currently_deployed']
          uncommitted_changes ||= version['uncommitted_changes']
          if currently_deployed && uncommitted_changes
            return true, true
          end
        end
      end
      return currently_deployed, uncommitted_changes
    end

    def release_version_details_for_old_director(releases)
      currently_deployed = false
      # old director did not support uncommitted changes
      uncommitted_changes = false
      releases.each do |release|
        currently_deployed ||= release['in_use'].any?
        if currently_deployed
          return true, uncommitted_changes
        end
      end
      return currently_deployed, uncommitted_changes
    end

    def should_convert_to_old_format?(version)
      director_version = director.get_status['version']
      new_format_director_version = '1.2580.0'
      if Bosh::Common::Version::BoshVersion.parse(director_version) >=
        Bosh::Common::Version::BoshVersion.parse(new_format_director_version)
        return false
      end

      old_format = Bosh::Common::Version::ReleaseVersion.parse(version).to_old_format
      old_format && version != old_format
    end

  end
end
