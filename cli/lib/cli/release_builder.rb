# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  class ReleaseBuilder
    include Bosh::Cli::DependencyHelper
    include Bosh::Cli::VersionCalc

    DEFAULT_RELEASE_NAME = "bosh_release"

    attr_reader :release, :packages, :jobs, :version

    # @param [Bosh::Cli::Release] release Current release
    # @param [Array<Bosh::Cli::PackageBuilder>] packages Built packages
    # @param [Array<Bosh::Cli::JobBuilder>] jobs Built jobs
    # @param [Hash] options Release build options
    def initialize(release, packages, jobs, options = { })
      @release = release
      @final = options.has_key?(:final) ? !!options[:final] : false
      @packages = packages
      @jobs = jobs

      @final_index = VersionsIndex.new(final_releases_dir, release_name)
      @dev_index = VersionsIndex.new(dev_releases_dir, release_name)
      @index = @final ? @final_index : @dev_index

      create_release_build_dir
    end

    # @return [String] Release name
    def release_name
      name = @final ? @release.final_name : @release.dev_name
      name.blank? ? DEFAULT_RELEASE_NAME : name
    end

    # @return [String] Release version
    def version
      @version ||= assign_version
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
        say("%-40s %s" % [package.name.green,
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
        say("%-40s %s" % [job.name.green, pretty_size(job.tarball_path)])
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
          "dependencies" => package.dependencies
        }
      end

      manifest["jobs"] = jobs.map do |job|
        {
          "name" => job.name,
          "version" => job.version,
          "sha1" => job.checksum,
        }
      end

      manifest["name"] = release_name

      unless manifest["name"].bosh_valid_id?
        raise InvalidRelease, "Release name `#{manifest["name"]}' " +
                              "is not a valid BOSH identifier"
      end

      fingerprint = make_fingerprint(manifest)

      if @index[fingerprint]
        old_version = @index[fingerprint]["version"]
        say("This version is no different from version #{old_version}")
        @version = old_version
      else
        @version = assign_version
        @index.add_version(fingerprint, { "version" => @version })
      end

      manifest["version"] = @version
      manifest_yaml = YAML.dump(manifest)

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
      return if @index.version_exists?(@version)

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
      File.join(@release.dir, "releases")
    end

    def dev_releases_dir
      File.join(@release.dir, "dev_releases")
    end

    def tarball_path
      File.join(releases_dir, "#{release_name}-#{version}.tgz")
    end

    def manifest_path
      File.join(releases_dir, "#{release_name}-#{version}.yml")
    end

    def make_fingerprint(item)
      case item
      when Array
        source = item.map { |e| make_fingerprint(e) }.sort.join("")
      when Hash
        source = item.keys.sort.map{ |k| make_fingerprint(item[k]) }.join("")
      else
        source = item.to_s
      end
      Digest::SHA1.hexdigest(source)
    end

    private

    def version=(version)
      @version = version
    end

    def assign_version
      latest_final_version = @final_index.latest_version.to_i
      latest_dev_version = @dev_index.latest_version(latest_final_version)

      if @final
        latest_final_version + 1
      else
        major = latest_final_version
        minor = minor_version(latest_dev_version).to_i + 1
        "#{major}.#{minor}-dev"
      end
    end

    def build_dir
      @build_dir ||= Dir.mktmpdir
    end

    def create_release_build_dir
      in_build_dir do
        FileUtils.mkdir("packages")
        FileUtils.mkdir("jobs")
      end
    end

    def in_build_dir(&block)
      Dir.chdir(build_dir) { yield }
    end

  end

end
