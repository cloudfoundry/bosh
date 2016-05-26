module Bosh::Cli
  class ReleaseBuilder
    include Bosh::Cli::DependencyHelper

    attr_reader(
      :release,
      :license,
      :packages,
      :jobs,
      :name,
      :version,
      :build_dir,
      :commit_hash,
      :uncommitted_changes
    )

    # @param [Bosh::Cli::Release] release Current release
    # @param [Array<Bosh::Cli::BuildArtifact>] package_artifacts Built packages
    # @param [Array<Bosh::Cli::BuildArtifact>] job_artifacts Built jobs
    # @param [Hash] options Release build options
    def initialize(release, package_artifacts, job_artifacts, license_artifact, name, options = { })
      @release = release
      @final = options.has_key?(:final) ? !!options[:final] : false
      @commit_hash = options.fetch(:commit_hash, '00000000')
      @uncommitted_changes = options.fetch(:uncommitted_changes, true)
      @packages = package_artifacts # todo
      @jobs = job_artifacts # todo
      @license = license_artifact
      @name = name
      raise 'Release name is blank' if name.blank?

      @timestamp_version = options.fetch(:'timestamp_version', false)
      @version = options.fetch(:version, nil)

      @final_index = Versions::VersionsIndex.new(final_releases_dir)
      @dev_index = Versions::VersionsIndex.new(dev_releases_dir)
      @index = @final ? @final_index : @dev_index
      @release_storage = Versions::LocalArtifactStorage.new(@index.storage_dir)

      if @version && @release_storage.has_file?(release_filename)
        raise ReleaseVersionError.new('Release version already exists')
      end

      @build_dir = Dir.mktmpdir

      in_build_dir do
        FileUtils.mkdir("packages")
        FileUtils.mkdir("jobs")
      end
    end

    # @return [String] Release version
    def version
      @version ||= assign_version.to_s
    end

    # @return [Boolean] Is release final?
    def final?
      @final
    end

    def release_filename
      "#{@name}-#{@version}.tgz"
    end

    # @return [Array<Bosh::Cli::BuildArtifact>] List of job artifacts
    #   affected by this release compared to the previous one.
    def affected_jobs
      result = Set.new(@jobs.select { |job_artifact| job_artifact.new_version? })
      return result.to_a if @packages.empty?

      new_package_names = @packages.map do |package_artifact|
        package_artifact.name if package_artifact.new_version?
      end.compact

      @jobs.each do |job|
        result << job if (new_package_names & job.dependencies).size > 0
      end

      result.to_a
    end

    # Builds release
    # @param [Hash] options Release build options
    def build(options = {})
      options = { :generate_tarball => true }.merge(options)

      header("Generating manifest...")
      manifest_path = generate_manifest
      if options[:generate_tarball]
        generate_tarball(manifest_path)
      end
      @build_complete = true
    end

    # Generates release manifest
    def generate_manifest
      manifest = {}
      manifest['packages'] = packages.map do |build_artifact|
        {
          'name' => build_artifact.name,
          'version' => build_artifact.version,
          'fingerprint' => build_artifact.fingerprint,
          'sha1' => build_artifact.sha1,
          'dependencies' => build_artifact.dependencies,
        }
      end

      manifest['jobs'] = jobs.map do |build_artifact|
        {
          'name' => build_artifact.name,
          'version' => build_artifact.version,
          'fingerprint' => build_artifact.fingerprint,
          'sha1' => build_artifact.sha1,
        }
      end

      unless @license.nil?
        manifest['license'] = {
          'version' => @license.version,
          'fingerprint' => @license.fingerprint,
          'sha1' => @license.sha1,
        }
      end

      manifest['commit_hash'] = commit_hash
      manifest['uncommitted_changes'] = uncommitted_changes

      unless @name.bosh_valid_id?
        raise InvalidRelease, "Release name '#{@name}' is not a valid BOSH identifier"
      end
      manifest['name'] = @name

      # New release versions are allowed to have the same fingerprint as old versions.
      # For reverse compatibility, random uuids are stored instead.
      @index.add_version(SecureRandom.uuid, { 'version' => version })

      manifest['version'] = version
      manifest_yaml = Psych.dump(manifest)

      say("Writing manifest...")
      File.open(File.join(build_dir, "release.MF"), "w") do |f|
        f.write(manifest_yaml)
      end

      File.open(manifest_path, "w") do |f|
        f.write(manifest_yaml)
      end

      @manifest_generated = true
      manifest_path
    end

    def generate_tarball(manifest_path = nil)
      manifest_path ||= generate_manifest
      return if @release_storage.has_file?(release_filename)

      archiver = ReleaseArchiver.new(tarball_path, manifest_path, packages, jobs, license)
      archiver.build
    end

    def releases_dir
      @final ? final_releases_dir : dev_releases_dir
    end

    def final_releases_dir
      File.join(@release.dir, 'releases', @name)
    end

    def dev_releases_dir
      File.join(@release.dir, 'dev_releases', @name)
    end

    def tarball_path
      File.join(releases_dir, "#{@name}-#{version}.tgz")
    end

    def manifest_path
      File.join(releases_dir, "#{@name}-#{version}.yml")
    end

    private

    # Copies packages into release
    def copy_packages
      header("Copying packages...")
      packages.each do |package_artifact|
        copy_artifact(package_artifact, 'packages')
      end
      nl
    end

    def assign_version
      latest_final_version = Versions::ReleaseVersionsIndex.new(@final_index).latest_version
      latest_final_version ||= Bosh::Common::Version::ReleaseVersion.parse('0')

      if @final
        # Drop pre-release and post-release segments, and increment the release segment
        if @timestamp_version
          raise ReleaseVersionError.new('Release version cannot be set to a timestamp for a final release')
        end

        latest_final_version.increment_release
      else
        # Increment or Reset the post-release segment
        dev_versions = Versions::ReleaseVersionsIndex.new(@dev_index).versions
        latest_dev_version = dev_versions.latest_with_pre_release(latest_final_version)

        if latest_dev_version
          if @timestamp_version
            latest_dev_version.timestamp_release
          elsif latest_dev_version.version.post_release.nil?
            latest_dev_version.default_post_release
          else
            latest_dev_version.increment_post_release
          end
        else
          if @timestamp_version
            latest_final_version.timestamp_release
          else
            latest_final_version.default_post_release
          end
        end
      end
    end

    def in_build_dir(&block)
      Dir.chdir(build_dir) { yield }
    end
  end
end
