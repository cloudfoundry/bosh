require File.expand_path(File.dirname(__FILE__) + '/../../release_print_helper.rb')
module Bosh::Cli::Command
  module Release
    class FinalizeRelease < Base
      include ReleasePrintHelper
      include Bosh::Cli::DependencyHelper

      # bosh finalize release
      usage 'finalize release'
      desc 'Create final release from dev release tarball (assumes current directory to be a release repository)'
      option '--dry-run', 'stop before writing release manifest'
      option '--name NAME', 'specify a custom release name'
      option '--version VERSION', 'specify a custom version number (ex: 1.0.0 or 1.0-beta.2+dev.10)'

      def finalize(tarball_path)
        options[:final] = true

        # validate preconditions
        check_if_release_dir

        tarball = extract_and_validate_tarball(tarball_path)

        manifest = Psych.load(tarball.manifest)

        dev_release_name = manifest["name"]
        dev_release_ver = manifest["version"]
        final_release_name = options[:name] || dev_release_name

        final_release_dir = File.join('releases', final_release_name)
        @release_index = Bosh::Cli::Versions::VersionsIndex.new(final_release_dir)
        final_release_ver = options[:version] || next_final_version

        if options[:version] && @release_index.version_strings.include?(options[:version])
          raise Bosh::Cli::ReleaseVersionError.new('Release version already exists')
        end

        @progress_renderer = Bosh::Cli::InteractiveProgressRenderer.new

        if !options[:dry_run] then
          release.blobstore # prime & validate blobstore config

          manifest["version"] = final_release_ver
          manifest["name"] = final_release_name

          updated_manifest = upload_package_and_job_blobs(manifest, tarball)

          tarball.replace_manifest(updated_manifest)

          FileUtils.mkdir_p(final_release_dir)
          final_release_manifest_path = File.absolute_path(File.join(final_release_dir, "#{final_release_name}-#{final_release_ver}.yml"))
          File.open(final_release_manifest_path, 'w') do |release_manifest_file|
            release_manifest_file.puts(tarball.manifest)
          end

          @release_index.add_version(SecureRandom.uuid, "version" => final_release_ver)

          final_release_tarball_path = File.absolute_path(File.join(final_release_dir, "#{final_release_name}-#{final_release_ver}.tgz"))
          tarball.create_from_unpacked(final_release_tarball_path)

          nl
          say("Creating final release #{final_release_name}/#{final_release_ver} from dev release #{dev_release_name}/#{dev_release_ver}")

          release.latest_release_filename = final_release_manifest_path
          release.save_config

          header('Release summary')
          show_summary(tarball)
          nl

          say("Release name: #{final_release_name.make_green}")
          say("Release version: #{final_release_ver.to_s.make_green}")
          say("Release manifest: #{release.latest_release_filename.make_green}")
          say("Release tarball (#{pretty_size(final_release_tarball_path)}): " + final_release_tarball_path.make_green)
        end
      end

      private

      def upload_package_and_job_blobs(manifest, tarball)
        manifest['packages'].map! do |package|
          upload_to_blobstore(package.dup, 'packages', tarball.package_tarball_path(package['name']))
        end

        manifest['jobs'].map! do |job|
          upload_to_blobstore(job.dup, 'jobs', tarball.job_tarball_path(job['name']))
        end

        if manifest['license']
          # the licence is different from packages and jobs: it has to be rebuilt from the
          # raw LICENSE and/or NOTICE files in the dev release tarball
          updated_artifact = archive_builder.build(tarball.license_resource)
          manifest['license'] = {
            'version' => updated_artifact.version,
            'fingerprint' => updated_artifact.fingerprint,
            'sha1' => updated_artifact.sha1,
          }
        end
        manifest
      end

      def extract_and_validate_tarball(tarball_path)
        tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)
        err("Cannot find release tarball #{tarball_path}") if !tarball.exists?

        err("#{tarball_path} is not a valid release tarball") if !tarball.valid?(:print_release_info => false)
        tarball
      end

      def next_final_version
        latest_final_version = Bosh::Cli::Versions::ReleaseVersionsIndex.new(@release_index).latest_version || Bosh::Common::Version::ReleaseVersion.parse('0')
        latest_final_version.increment_release.to_s
      end

      def upload_to_blobstore(artifact, plural_type, artifact_path)
        err("Cannot find artifact complete information, please upgrade tarball to newer version") if !artifact['fingerprint']

        final_builds_index = final_builds_for_artifact(plural_type, artifact)

        if final_builds_index[artifact['fingerprint']]
          artifact['sha1'] = final_builds_index[artifact['fingerprint']]['sha1']
          return artifact
        end

        @progress_renderer.start(artifact['name'], "uploading...")
        blobstore_id = nil
        File.open(artifact_path, 'r') do |f|
          blobstore_id = @release.blobstore.create(f)
        end

        final_builds_index.add_version(artifact['fingerprint'], {
            'version' => artifact['version'],
            'sha1' => artifact['sha1'],
            'blobstore_id' => blobstore_id
          })
        @progress_renderer.finish(artifact['name'], "uploaded")
        artifact
      end

      def archive_builder
        @archive_builder ||= Bosh::Cli::ArchiveBuilder.new(archive_repository_provider,
                                                           :final => true, :dry_run => false)
      end

      def archive_repository_provider
        @archive_repository_provider ||= Bosh::Cli::ArchiveRepositoryProvider.new(work_dir, cache_dir, release.blobstore)
      end

      def final_builds_for_artifact(plural_type, artifact)
        final_builds_dir = File.join('.final_builds', plural_type, artifact['name']).to_s
        FileUtils.mkdir_p(final_builds_dir)
        Bosh::Cli::Versions::VersionsIndex.new(final_builds_dir)
      end
    end
  end
end
