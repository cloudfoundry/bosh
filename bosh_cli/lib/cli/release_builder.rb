module Bosh::Cli
  class ReleaseBuilder
    include Bosh::Cli::DependencyHelper

    attr_reader(
      :release,
      :license_artifact,
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
      @license_artifact = license_artifact
      @name = name
      raise 'Release name is blank' if name.blank?

      @version = options.fetch(:version, nil)

      raise ReleaseVersionError.new('Version numbers cannot be specified for dev releases') if (@version && !@final)

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
      generate_manifest
      if options[:generate_tarball]
        header("Generating tarball...")
        generate_tarball
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

      unless @license_artifact.nil?
        manifest['license'] = {
          'version' => @license_artifact.version,
          'fingerprint' => @license_artifact.fingerprint,
          'sha1' => @license_artifact.sha1,
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
    end

    def generate_tarball
      generate_manifest unless @manifest_generated
      return if @release_storage.has_file?(release_filename)

      copy_jobs
      copy_packages
      copy_license

      FileUtils.mkdir_p(File.dirname(tarball_path))

      in_build_dir do
        `tar -czf #{tarball_path} . 2>&1`
        unless $?.exitstatus == 0
          raise InvalidRelease, "Cannot create release tarball"
        end
        say("Generated #{tarball_path}")
      end
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

    # Copies jobs into release todo DRY vs copy_packages
    def copy_jobs
      header("Copying jobs...")
      jobs.each do |job_artifact|
        copy_artifact(job_artifact, 'jobs')
      end
      nl
    end

    def copy_license
      return if @license_artifact.nil?

      header("Copying license...")
      copy_artifact(@license_artifact)
      nl
    end

    def copy_artifact(artifact, dest = nil)
      name = artifact.name
      tarball_path = artifact.tarball_path
      say("%-40s %s" % [name.make_green, pretty_size(tarball_path)])
      FileUtils.cp(tarball_path,
        File.join([build_dir, dest, "#{name}.tgz"].compact),
        :preserve => true)
    end

    def assign_version
      latest_final_version = Versions::ReleaseVersionsIndex.new(@final_index).latest_version
      latest_final_version ||= Bosh::Common::Version::ReleaseVersion.parse('0')

      if @final
        # Drop pre-release and post-release segments, and increment the release segment
        latest_final_version.increment_release
      else
        # Increment or Reset the post-release segment
        dev_versions = Versions::ReleaseVersionsIndex.new(@dev_index).versions
        latest_dev_version = dev_versions.latest_with_pre_release(latest_final_version)

        if latest_dev_version
          if latest_dev_version.version.post_release.nil?
            latest_dev_version.default_post_release
          else
            latest_dev_version.increment_post_release
          end
        else
          latest_final_version.default_post_release
        end
      end
    end

    def in_build_dir(&block)
      Dir.chdir(build_dir) { yield }
    end
  end
end
