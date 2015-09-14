require File.expand_path(File.dirname(__FILE__) + '/../../release_print_helper.rb')
module Bosh::Cli::Command
  module Release
    class CreateRelease < Base
      include ReleasePrintHelper
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
      option '--dir RELEASE_DIRECTORY', 'path to release directory'

      def create(manifest_file = nil)
        switch_to_release_dir
        check_if_release_dir

        migrate_to_support_multiple_releases

        if manifest_file && File.file?(manifest_file)
          if options[:version]
            err('Cannot specify a custom version number when creating from a manifest. The manifest already specifies a version.'.make_red)
          end

          say('Recreating release from the manifest')
          Bosh::Cli::ReleaseCompiler.compile(manifest_file, cache_dir, release.blobstore, [], release.dir)
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
        err("Invalid version: '#{version}'. Please specify a valid version (ex: 1.0.0 or 1.0-beta.2+dev.10).".make_red)
      rescue Bosh::Cli::ReleaseVersionError => e
        err(e.message.make_red)
      end

      private

      def migrate_to_support_multiple_releases
        default_release_name = release.final_name

        # can't migrate without a default release name
        return if default_release_name.blank?

        Bosh::Cli::Versions::MultiReleaseSupport.new(release.dir, default_release_name, self).migrate
      end

      def create_from_spec(version)
        force = options[:force]
        name = options[:name]
        manifest_only = !options[:with_tarball]

        release.blobstore # prime & validate blobstore config

        dirty_blob_check(force)

        raise_dirty_state_error if dirty_state? && !force

        if final
          confirm_final_release
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

        say("Release artifact cache: #{cache_dir}")

        header('Building license')
        license_artifacts = build_licenses

        header('Building packages')
        package_artifacts = build_packages

        header('Building jobs')
        job_artifacts = build_jobs(package_artifacts.map { |artifact| artifact.name })

        header('Building release')
        release_builder = build_release(job_artifacts, manifest_only, package_artifacts, license_artifacts, name, version)

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

      def confirm_final_release
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

      def archive_repository_provider
        @archive_repository_provider ||= Bosh::Cli::ArchiveRepositoryProvider.new(release.dir, cache_dir, release.blobstore)
      end

      def build_release(job_artifacts, manifest_only, package_artifacts, license_artifacts, name, version)
        license_artifact = license_artifacts.first
        release_builder = Bosh::Cli::ReleaseBuilder.new(release, package_artifacts, job_artifacts, license_artifact, name,
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

      def build_packages
        packages = Bosh::Cli::Resources::Package.discover(release.dir)
        artifacts = packages.map do |package|
          say("Building #{package.name.make_green}...")
          artifact = archive_builder.build(package)
          nl
          artifact
        end

        if packages.size > 0
          package_index = artifacts.inject({}) do |index, artifact|
            index[artifact.name] = artifact.dependencies
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

      def build_jobs(packages)
        jobs = Bosh::Cli::Resources::Job.discover(release.dir, packages)
        artifacts = jobs.map do |job|
          say("Building #{job.name.make_green}...")
          artifact = archive_builder.build(job)
          nl
          artifact
        end

        artifacts
      end

      def build_licenses
        licenses = Bosh::Cli::Resources::License.discover(release.dir)
        artifacts = licenses.map do |license|
          say("Building #{'license'.make_green}...")
          artifact = archive_builder.build(license)
          nl
          artifact
        end.compact

        artifacts
      end

      def archive_builder
        @archive_builder ||= Bosh::Cli::ArchiveBuilder.new(archive_repository_provider,
          :final => final, :dry_run => dry_run)
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

      def commit_hash
        status = Bosh::Exec.sh('git show-ref --head --hash=8 2> /dev/null')
        status.output.split.first
      rescue Bosh::Exec::Error
        '00000000'
      end

      def dry_run
        dry_run ||= options[:dry_run]
      end

      def final
        final ||= options[:final]
      end
    end
  end
end
