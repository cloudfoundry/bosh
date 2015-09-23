# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  # Compiles release tarball based on manifest
  class ReleaseCompiler

    attr_writer :tarball_path

    def self.compile(manifest_file, artifacts_dir, blobstore, package_matches, release_source)
      new(manifest_file, artifacts_dir, blobstore, package_matches, release_source).compile
    end

    # @param [String] manifest_file Release manifest path
    # @param [Bosh::Blobstore::Client] blobstore Blobstore client
    # @param [Array] package_matches List of package checksums that director
    #   can match
    # @param [String] release_source Release directory
    def initialize(manifest_file, artifacts_dir, blobstore, package_matches, release_source)
      @blobstore = blobstore
      @release_source = release_source
      @manifest_path = File.expand_path(manifest_file, @release_source)
      @tarball_path = nil

      @artifacts_dir = artifacts_dir
      @build_dir = Dir.mktmpdir
      @jobs_dir = File.join(@build_dir, "jobs")
      @packages_dir = File.join(@build_dir, "packages")

      @package_matches = Set.new(package_matches)

      FileUtils.mkdir_p(@jobs_dir)
      FileUtils.mkdir_p(@packages_dir)

      @manifest = load_yaml_file(manifest_file)

      @name = @manifest["name"]
      @version = @manifest["version"]
      @packages = @manifest.fetch("packages", []).map { |pkg| OpenStruct.new(pkg) }
      @jobs = @manifest.fetch("jobs", []).map { |job| OpenStruct.new(job) }
      @license = @manifest["license"] ? OpenStruct.new(@manifest["license"]) : nil
    end

    def artifact_from(resource, type)
      return nil unless resource
      BuildArtifact.new(resource.name, resource.fingerprint, send(:"find_#{type}", resource), resource.sha1, [], nil, nil)
    end

    def compile
      if exists?
        quit("You already have this version in `#{tarball_path.make_green}'")
      end

      packages = @packages
        .reject { |package| remote_package_exists?(package) }
        .map { |package| artifact_from(package, :package) }
      jobs = @jobs
        .reject { |job| remote_job_exists?(job) }
        .map { |job| artifact_from(job, :job) }
      license = artifact_from(@license, :license)

      archiver = ReleaseArchiver.new(tarball_path, @manifest_path, packages, jobs, license)
      archiver.build
    end

    def exists?
      File.exists?(tarball_path)
    end

    def tarball_path
      @tarball_path || File.join(File.dirname(@manifest_path),
                                 "#{@name}-#{@version}.tgz")
    end

    def find_package(package)
      name = package.name
      final_package_dir = File.join(@release_source, '.final_builds', 'packages', name)
      final_index = Versions::VersionsIndex.new(final_package_dir)
      dev_package_dir = File.join(@release_source, '.dev_builds', 'packages', name)
      dev_index = Versions::VersionsIndex.new(dev_package_dir)
      find_in_indices(final_index, dev_index, package, 'package')
    end

    def find_job(job)
      name = job.name
      final_jobs_dir = File.join(@release_source, '.final_builds', 'jobs', name)
      final_index = Versions::VersionsIndex.new(final_jobs_dir)
      dev_jobs_dir = File.join(@release_source, '.dev_builds', 'jobs', name)
      dev_index = Versions::VersionsIndex.new(dev_jobs_dir)
      find_in_indices(final_index, dev_index, job, 'job')
    end

    def find_license(license)
      final_dir = File.join(@release_source, '.final_builds', 'license')
      final_index = Versions::VersionsIndex.new(final_dir)
      dev_dir = File.join(@release_source, '.dev_builds', 'license')
      dev_index = Versions::VersionsIndex.new(dev_dir)
      find_in_indices(final_index, dev_index, license, 'license')
    end

    def find_version_by_sha1(index, sha1)
      index.select{ |_, build| build['sha1'] == sha1 }.values.first
    end

    def find_in_indices(final_index, dev_index, build, build_type)
      desc = "#{build.name} (#{build.version})"

      index = final_index
      found_build = find_version_by_sha1(index, build.sha1)

      if found_build.nil?
        index = dev_index
        found_build = find_version_by_sha1(index, build.sha1)
      end

      if found_build.nil?
        say("MISSING".make_red)
        err("Cannot find #{build_type} with checksum `#{build.sha1}'")
      end

      sha1 = found_build["sha1"]
      blobstore_id = found_build["blobstore_id"]

      storage = Versions::LocalArtifactStorage.new(@artifacts_dir)

      resolver = Versions::VersionFileResolver.new(storage, @blobstore)
      resolver.find_file(blobstore_id, sha1, "#{build_type} #{desc}")
    rescue Bosh::Blobstore::BlobstoreError => e
      raise BlobstoreError, "Blobstore error: #{e}"
    end

    # Checks if local package is already known remotely
    # @param [#name, #version] local_package
    # @return [Boolean]
    def remote_package_exists?(local_package)
      # If checksum is known to director we can always match it
      @package_matches.include?(local_package.sha1) ||                     # !!! Needs test coverage
        (local_package.fingerprint &&                                      # !!! Needs test coverage
         @package_matches.include?(local_package.fingerprint))             # !!! Needs test coverage
    end

    # Checks if local job is already known remotely
    # @param [#name, #version] local_job
    # @return [Boolean]
    def remote_job_exists?(local_job)
      false
    end
  end
end
