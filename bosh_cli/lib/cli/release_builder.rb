module Bosh::Cli
  class ReleaseBuilder
    include Bosh::Cli::DependencyHelper

    attr_reader :release, :packages, :jobs, :name, :version, :build_dir, :commit_hash, :uncommitted_changes

    # @param [Bosh::Cli::Release] release Current release
    # @param [Array<Bosh::Cli::Resources::Package>] packages Built packages
    # @param [Array<Bosh::Cli::JobBuilder>] jobs Built jobs
    # @param [Hash] options Release build options
    def initialize(release, packages, jobs, name, options = { })
      @release = release
      @final = options.has_key?(:final) ? !!options[:final] : false
      @commit_hash = options.fetch(:commit_hash, '00000000')
      @uncommitted_changes = options.fetch(:uncommitted_changes, true)
      @packages = packages
      @jobs = jobs
      @name = name
      raise 'Release name is blank' if name.blank?

      @version = options.fetch(:version, nil)

      raise ReleaseVersionError.new('Version numbers cannot be specified for dev releases') if (@version && !@final)

      @final_index = Versions::VersionsIndex.new(final_releases_dir)
      @dev_index = Versions::VersionsIndex.new(dev_releases_dir)
      @index = @final ? @final_index : @dev_index
      @release_storage = Versions::LocalVersionStorage.new(@index.storage_dir, @name)

      if @version && @release_storage.has_file?(@version)
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

    # @return [Array] List of jobs affected by this release compared
    #   to the previous one.
    def affected_jobs
      result = Set.new(@jobs.select { |job| job.new_version? })
      return result if @packages.empty?

      new_package_names = @packages.inject([]) do |list, package|
        list << package.name if package.new_version?
        list
      end

      @jobs.each do |job|
        result << job if (new_package_names & job.packages).size > 0
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

    # Copies packages into release
    def copy_packages
      packages.each do |package|
        say("%-40s %s" % [package.name.make_green,
                           pretty_size(package.tarball_path)])
        FileUtils.cp(package.tarball_path,
                     File.join(build_dir, "packages", "#{package.name}.tgz"),
                     :preserve => true)
      end
      @packages_copied = true
    end

    # Copies jobs into release
    def copy_jobs
      jobs.each do |job|
        say("%-40s %s" % [job.name.make_green, pretty_size(job.tarball_path)])
        FileUtils.cp(job.tarball_path,
                     File.join(build_dir, "jobs", "#{job.name}.tgz"),
                     :preserve => true)
      end
      @jobs_copied = true
    end

    # Generates release manifest
    def generate_manifest
      manifest = {}
      manifest["packages"] = []

      manifest["packages"] = packages.map do |package|
        {
          "name" => package.name,
          "version" => package.version,
          "sha1" => package.checksum,
          "fingerprint" => package.fingerprint,
          "dependencies" => package.dependencies
        }
      end

      manifest["jobs"] = jobs.map do |job|
        {
          "name" => job.name,
          "version" => job.version,
          "fingerprint" => job.fingerprint,
          "sha1" => job.checksum,
        }
      end

      manifest["commit_hash"] = commit_hash
      manifest["uncommitted_changes"] = uncommitted_changes

      unless @name.bosh_valid_id?
        raise InvalidRelease, "Release name `#{@name}' is not a valid BOSH identifier"
      end
      manifest["name"] = @name

      # New release versions are allowed to have the same fingerprint as old versions.
      # For reverse compatibility, random uuids are stored instead.
      @index.add_version(SecureRandom.uuid, { "version" => version })

      manifest["version"] = version
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
      return if @release_storage.has_file?(@version)

      unless @jobs_copied
        header("Copying jobs...")
        copy_jobs
        nl
      end
      unless @packages_copied
        header("Copying packages...")
        copy_packages
        nl
      end

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
