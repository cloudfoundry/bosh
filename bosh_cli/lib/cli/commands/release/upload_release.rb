module Bosh::Cli::Command
  module Release
    class UploadRelease < Base

      usage 'upload release'
      desc "Upload release (release_file can be a local file or a remote URI). \
If --name & --version are provided, they will be used for checking if release exists & upload will be skipped if it exists (for both local and remote)"
      option '--rebase',
        'Rebases this release onto the latest version',
        'known by director (discards local job/package',
        'versions in favor of versions assigned by director)'
      option '--skip-if-exists', 'no-op; retained for backward compatibility'
      option '--dir RELEASE_DIRECTORY', 'path to release directory'
      option '--sha1 SHA1', 'SHA1 of the remote release'
      option '--name NAME', 'name of the release'
      option '--version VERSION', 'version of the release'
      option '--fix', 'verify blobstore contents and replace with correct versions'

      def upload(release_file = nil)
        auth_required
        switch_to_release_dir
        show_current_state

        upload_options = {
          :rebase => options[:rebase],
          :repack => true,
          :sha1 => options[:sha1],
          :fix => options[:fix],
        }

        #only check release_dir if not compiled release tarball
        file_type = `file --mime-type -b '#{release_file}'`

        compiled_release = false
        if file_type == /application\/x-gzip/
          tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)
          compiled_release = tarball.compiled_release?
        end

        if release_file.nil? and !compiled_release
          check_if_release_dir
          release_file = release.latest_release_filename
          if release_file.nil?
            err('The information about latest generated release is missing, please provide release filename')
          end
        end

        if !options[:fix] && options[:name] && options[:version]
          say("Checking whether release #{options[:name]}/#{options[:version]} already exists...".make_green, '')
          director.list_releases.each do |release|
            if release['name'] == options[:name]
              release['release_versions'].each do |version|
                if version['version'] == options[:version]
                  say('YES'.make_yellow)
                  return
                end
              end
            end
          end
          say('NO'.make_yellow)
        end

        if release_file =~ /^#{URI::regexp}$/
          upload_remote_release(release_file, upload_options)

        else
          err("Option '--sha1' is not supported for uploading local release") unless options[:sha1].nil?
          err("Release file doesn't exist") unless File.exist?(release_file)

          file_type = `file --mime-type -b '#{release_file}'` # duplicate? Already done on line 23

          if file_type =~ /text\/(plain|yaml)/
            upload_manifest(release_file, upload_options)
          else
            upload_tarball(release_file, upload_options)
          end
        end
      end

      private

      def upload_manifest(manifest_path, upload_options = {})
        package_matches = upload_options[:fix] ? [] : match_remote_packages(File.read(manifest_path))

        find_release_dir(manifest_path)

        blobstore = release.blobstore
        tmpdir = Dir.mktmpdir

        compiler = Bosh::Cli::ReleaseCompiler.new(manifest_path, cache_dir, blobstore, package_matches, release.dir)
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
        fix = upload_options[:fix]

        say("\nVerifying manifest...")
        tarball.validate_manifest
        nl

        if should_convert_to_old_format?(tarball.version)
          msg = "You are using CLI > 1.2579.0 with a director that doesn't support " +
            'the new version format you are using. Upgrade your ' +
            'director to match the version of your CLI or downgrade your ' +
            'CLI to 1.2579.0 to avoid versioning mismatch issues.'

          say(msg.make_yellow)
          tarball_path = tarball.convert_to_old_format
        end

        Bosh::Common::Version::ReleaseVersion.parse(tarball.version) if new_director?

        begin
          if repack && !fix
            if tarball.compiled_release?
              package_matches = match_remote_compiled_packages(tarball.manifest)
            else
              package_matches = match_remote_packages(tarball.manifest)
            end

            # if the director is an older version that doesn't support optimized unpack we
            # have to upload everything
            if tarball.upload_packages?(package_matches) || !director_supports_fast_unpack?
              tarball.validate(:allow_sparse => true, :validate_manifest => false)
              err('Release is invalid, please fix, verify and upload again') unless tarball.valid?
            else
              tarball.validate_jobs(:allow_sparse => true, :validate_job_packages => false)
              tarball.print_manifest
            end

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
          report = 'Release rebased'
        else
          say("\nUploading release\n")
          report = 'Release uploaded'
        end

        status, task_id = director.upload_release(tarball_path, rebase: rebase, fix: fix)
        task_report(status, task_id, report)
      end

      def upload_remote_release(release_location, upload_options = {})
        if upload_options[:rebase]
          say("Using remote release `#{release_location}' (#{'will be rebased'.make_yellow})")
          report = 'Release rebased'
        else
          say("Using remote release `#{release_location}'")
          report = 'Release uploaded'
        end

        status, task_id = director.upload_remote_release(
          release_location,
          rebase: upload_options[:rebase],
          sha1: upload_options[:sha1],
          fix: upload_options[:fix]
        )
        task_report(status, task_id, report)
      end

      def find_release_dir(manifest_path)
        release_dir_for_final_manfiest = File.expand_path('../..', manifest_path)
        release_dir_for_dev_manfiest = File.expand_path('../../..', manifest_path)

        [
          release_dir_for_final_manfiest,
          release_dir_for_dev_manfiest
        ].each do |release_dir|
          @release_directory = release_dir
          break if in_release_dir?
        end
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
      end

      def match_remote_compiled_packages(manifest_yaml)
        director.match_compiled_packages(manifest_yaml)
      rescue Bosh::Cli::DirectorError
        msg = "You are using CLI >= 0.20 with director that doesn't support " +
            "package matches.\nThis will result in uploading all packages " +
            "and jobs to your director.\nIt is recommended to update your " +
            'director or downgrade your CLI to 0.19.6'

        say(msg.make_yellow)
      end

      def should_convert_to_old_format?(version)
        return false if new_director?
        old_format = Bosh::Common::Version::ReleaseVersion.parse(version).to_old_format
        old_format && version != old_format
      end

      def new_director?
        director_version = director.get_status['version']
        new_format_director_version = '1.2580.0'
        Bosh::Common::Version::BoshVersion.parse(director_version) >=
          Bosh::Common::Version::BoshVersion.parse(new_format_director_version)
      end

      def director_supports_fast_unpack?
        director_version = director.get_status['version']
        new_format_director_version = '1.3100.0'
        Bosh::Common::Version::BoshVersion.parse(director_version) >
            Bosh::Common::Version::BoshVersion.parse(new_format_director_version)
      end
    end
  end
end
