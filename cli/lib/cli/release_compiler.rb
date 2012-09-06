# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  # Compiles release tarball based on manifest
  class ReleaseCompiler

    attr_writer :tarball_path

    def self.compile(manifest_file, blobstore)
      new(manifest_file, blobstore).compile
    end

    # @param [String] manifest_file Release manifest path
    # @param [Bosh::Blobstore::Client] blobstore Blobstore client
    # @param [Array] package_matches List of package checksums that director
    #   can match
    # @param [String] release_dir Release directory
    def initialize(manifest_file, blobstore,
                   package_matches = [], release_dir = nil)

      @blobstore = blobstore
      @release_dir = release_dir || Dir.pwd
      @manifest_file = File.expand_path(manifest_file, @release_dir)
      @tarball_path = nil

      @build_dir = Dir.mktmpdir
      @jobs_dir = File.join(@build_dir, "jobs")
      @packages_dir = File.join(@build_dir, "packages")

      @package_matches = Set.new(package_matches)

      FileUtils.mkdir_p(@jobs_dir)
      FileUtils.mkdir_p(@packages_dir)

      @manifest = load_yaml_file(manifest_file)

      @name = @manifest["name"]
      @version = @manifest["version"]
      @packages = @manifest["packages"].map { |pkg| OpenStruct.new(pkg) }
      @jobs = @manifest["jobs"].map { |job| OpenStruct.new(job) }
    end

    def compile
      if exists?
        quit("You already have this version in `#{tarball_path.green}'")
      end

      FileUtils.cp(@manifest_file,
                   File.join(@build_dir, "release.MF"),
                   :preserve => true)

      header("Copying packages")
      @packages.each do |package|
        say("#{package.name} (#{package.version})".ljust(30), " ")
        if remote_package_exists?(package)
          say("SKIP".yellow)
          next
        end
        package_filename = find_package(package)
        if package_filename.nil?
          err("Cannot find package `#{package.name} (#{package.version})'")
        end
        FileUtils.cp(package_filename,
                     File.join(@packages_dir, "#{package.name}.tgz"),
                     :preserve => true)
      end

      header("Copying jobs")
      @jobs.each do |job|
        say("#{job.name} (#{job.version})".ljust(30), " ")
        if remote_job_exists?(job)
          say("SKIP".yellow)
          next
        end
        job_filename = find_job(job)
        if job_filename.nil?
          err("Cannot find job `#{job.name} (#{job.version})")
        end
        FileUtils.cp(job_filename,
                     File.join(@jobs_dir, "#{job.name}.tgz"),
                     :preserve => true)
      end

      header("Building tarball")
      Dir.chdir(@build_dir) do
        tar_out = `tar -czf #{tarball_path} . 2>&1`
        unless $?.exitstatus == 0
          raise InvalidRelease, "Cannot create release tarball: #{tar_out}"
        end
        say("Generated #{tarball_path.green}")
        say("Release size: #{pretty_size(tarball_path).green}")
      end
    end

    def exists?
      File.exists?(tarball_path)
    end

    def tarball_path
      @tarball_path || File.join(File.dirname(@manifest_file),
                                 "#{@name}-#{@version}.tgz")
    end

    def find_package(package)
      final_index = VersionsIndex.new(
          File.join(@release_dir, ".final_builds", "packages", package.name))
      dev_index = VersionsIndex.new(
          File.join(@release_dir, ".dev_builds", "packages", package.name))
      find_in_indices(final_index, dev_index, package)
    end

    def find_job(job)
      final_index = VersionsIndex.new(
          File.join(@release_dir, ".final_builds", "jobs", job.name))
      dev_index = VersionsIndex.new(
          File.join(@release_dir, ".dev_builds", "jobs", job.name))
      find_in_indices(final_index, dev_index, job)
    end

    def find_in_indices(final_index, dev_index, object)
      desc = "#{object.name} (#{object.version})"

      index = final_index
      build_data = index.find_by_checksum(object.sha1)

      if build_data.nil?
        index = dev_index
        build_data = index.find_by_checksum(object.sha1)
      end

      if build_data.nil?
        say("MISSING".red)
        err("Cannot find object with given checksum")
      end

      version = build_data["version"]
      sha1 = build_data["sha1"]
      blobstore_id = build_data["blobstore_id"]
      filename = index.filename(version)

      if File.exists?(filename)
        say("FOUND LOCAL".green)
        if Digest::SHA1.file(filename) != sha1
          err("#{desc} is corrupted locally")
        end
      elsif blobstore_id
        say("FOUND REMOTE".yellow)
        say("Downloading #{blobstore_id.to_s.green}...")

        payload = @blobstore.get(blobstore_id)

        if Digest::SHA1.hexdigest(payload) == sha1
          File.open(filename, "w") { |f| f.write(payload) }
        else
          err("#{desc} is corrupted in blobstore (id=#{blobstore_id})")
        end
      end

      File.exists?(filename) ? filename : nil

    rescue Bosh::Blobstore::BlobstoreError => e
      raise BlobstoreError, "Blobstore error: #{e}"
    end

    # Checks if local package is already known remotely
    # @param [#name, #version] local_package
    # @return [Boolean]
    def remote_package_exists?(local_package)
      # If checksum is known to director we can always match it
      @package_matches.include?(local_package.sha1) ||
        (local_package.fingerprint &&
         @package_matches.include?(local_package.fingerprint))
    end

    # Checks if local job is already known remotely
    # @param [#name, #version] local_job
    # @return [Boolean]
    def remote_job_exists?(local_job)
      false
    end
  end

end
