module Bosh::Cli::Command
  module Release
    class UploadRelease < Base

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
          msg = "You are using CLI > 1.2579.0 with a director that doesn't support " +
            'the new version format you are using. Upgrade your ' +
            'director to match the version of your CLI or downgrade your ' +
            'CLI to 1.2579.0 to avoid versioning mismatch issues.'

          say(msg.make_yellow)
          tarball_path = tarball.convert_to_old_format
        end

        remote_release = get_remote_release(tarball.release_name) rescue nil
        if remote_release && !rebase
          version = if new_director?
                      Bosh::Common::Version::ReleaseVersion.parse(tarball.version)
                    else
                      tarball.version
                    end
          if remote_release['versions'].include?(version.to_s)
            if upload_options[:skip_if_exists]
              say("Release `#{tarball.release_name}/#{version}' already exists. Skipping upload.")
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
          report = 'Release rebased'
        else
          say("\nUploading release\n")
          report = 'Release uploaded'
        end
        status, task_id = director.upload_release(tarball_path, rebase: rebase)
        task_report(status, task_id, report)
      end

      def upload_remote_release(release_location, upload_options = {})
        nl
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
          skip_if_exists: upload_options[:skip_if_exists],
        )
        task_report(status, task_id, report)
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
    end
  end
end
