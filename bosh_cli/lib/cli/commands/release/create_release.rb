module Bosh::Cli::Command
  module Release
    class CreateRelease < Base
      include Bosh::Cli::DependencyHelper

      DEFAULT_RELEASE_NAME = 'bosh-release'

      # bosh create release
      usage 'create release'
      desc 'Create release (assumes current directory to be a release repository)'
      option '--force', 'bypass git dirty state check'
      option '--final', 'create final release'
      option '--with-tarball', 'create release tarball'
      option '--dry-run', 'stop before writing release manifest'
      option '--name NAME', 'specify a custom release name'
      option '--version VERSION', 'specify a custom version number (ex: 1.0.0 or 1.0-beta.2+dev.10)'

      def create(manifest_file = nil)
        check_if_release_dir

        migrate_to_support_multiple_releases

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

      private

      def migrate_to_support_multiple_releases
        default_release_name = release.final_name

        # can't migrate without a default release name
        return if default_release_name.blank?

        Bosh::Cli::Versions::MultiReleaseSupport.new(@work_dir, default_release_name, self).migrate
      end

      def create_from_spec(version)
        final = options[:final]
        force = options[:force]
        name = options[:name]
        manifest_only = !options[:with_tarball]
        dry_run = options[:dry_run]

        release.blobstore # prime & validate blobstore config

        dirty_blob_check(force)

        raise_dirty_state_error if dirty_state? && !force

        if final
          confirm_final_release(dry_run)
          unless name
            save_final_release_name if release.final_name.blank?
            name = release.final_name
          end
          header('Building FINAL release'.make_green)
        else
          unless name
            save_dev_release_name if release.dev_name.blank?
            name = release.dev_name
          end
          header('Building DEV release'.make_green)
        end

        header('Building packages')
        package_artifacts = build_packages(dry_run, final)

        header('Building jobs')
        jobs = build_jobs(package_artifacts.map { |package| package['name'] }, dry_run, final)

        header('Building release')
        release_builder = build_release(dry_run, final, jobs, manifest_only, package_artifacts, name, version)

        header('Release summary')
        show_summary(release_builder)
        nl

        return nil if dry_run

        say("Release name: #{name.make_green}")
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
        options = {
          dry_run: dry_run,
          final: final
        }
        packages = Bosh::Cli::Resources::Package.discover(work_dir)
        artifacts = packages.map do |package|
          say("Building #{package.name.make_green}...")
          artifact = Bosh::Cli::ArchiveBuilder.new(package, work_dir, release.blobstore, options).build
          nl
          artifact
        end

        if packages.size > 0
          package_index = artifacts.inject({}) do |index, artifact|
            index[artifact['name']] = artifact['dependencies']
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

        artifacts
      end

      def build_release(dry_run, final, jobs, manifest_only, packages, name, version)
        release_builder = Bosh::Cli::ReleaseBuilder.new(release, packages, jobs, name,
          final: final,
          commit_hash: commit_hash,
          version: version,
          uncommitted_changes: dirty_state?
        )

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

      def show_summary(builder)
        packages_table = table do |t|
          t.headings = %w(Name Version Notes)
          builder.packages.each do |package|
            t << package_summary(package)
          end
        end

        jobs_table = table do |t|
          t.headings = %w(Name Version Notes)
          builder.jobs.each do |job|
            t << job_summary(job)
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

      def package_summary(artifact)
        result = []
        result << artifact['name']
        result << artifact['version']
        result << artifact['notes'].join(', ')
        result
      end

      def job_summary(artifact)
        result = []
        result << artifact.name
        result << artifact.version
        result << artifact.notes.join(', ')
        result
      end

      def commit_hash
        status = Bosh::Exec.sh('git show-ref --head --hash=8 2> /dev/null')
        status.output.split.first
      rescue Bosh::Exec::Error
        '00000000'
      end
    end
  end
end
