module Bosh::Cli
  class ReleaseTarball
    include Validation
    include DependencyHelper

    attr_reader :release_name, :jobs, :packages, :version
    attr_reader :skipped # Mostly for tests

    def initialize(tarball_path)
      @tarball_path = File.expand_path(tarball_path, Dir.pwd)
      @unpack_dir   = Dir.mktmpdir
      @jobs = []
      @packages = []
    end

    # Unpacks tarball to @unpack_dir, returns true if succeeded, false if failed
    def unpack
      return @unpacked unless @unpacked.nil?
      `tar -C #{@unpack_dir} -xzf #{@tarball_path} 2>&1`
      @unpacked = $?.exitstatus == 0
    end

    def exists?
      File.exists?(@tarball_path) && File.readable?(@tarball_path)
    end

    def manifest
      return nil unless valid?
      unpack
      File.read(File.join(@unpack_dir, "release.MF"))
    end

    # Repacks tarball according to the structure of remote release
    # Return path to repackaged tarball or nil if repack has failed
    def repack(remote_release = nil, package_matches = [])
      return nil unless valid?
      unpack

      tmpdir = Dir.mktmpdir
      repacked_path = File.join(tmpdir, "release-repack.tgz")

      at_exit { FileUtils.rm_rf(tmpdir) }

      manifest = load_yaml_file(File.join(@unpack_dir, "release.MF"))

      # Remote release could be not-existent, then package matches are supposed
      # to satisfy everything
      remote_release ||= {"jobs" => [], "packages" => []}

      local_packages = manifest["packages"]
      local_jobs = manifest["jobs"]
      remote_packages = remote_release["packages"]
      remote_jobs = remote_release["jobs"]

      @skipped = 0

      Dir.chdir(@unpack_dir) do
        # TODO: this code can be dried up a little bit (as it is somewhat
        # similar to what's going on in ReleaseCompiler)

        local_packages.each do |package|
          say("#{package["name"]} (#{package["version"]})".ljust(30), " ")
          if package_matches.include?(package["sha1"]) ||
            remote_packages.any? { |rp| package["name"] == rp["name"] &&
              package["version"].to_s == rp["version"].to_s }
            say("SKIP".green)
            @skipped += 1
            FileUtils.rm_rf(File.join("packages", "#{package["name"]}.tgz"))
          else
            say("UPLOAD".red)
          end
        end

        local_jobs.each do |job|
          say("#{job["name"]} (#{job["version"]})".ljust(30), " ")
          if remote_jobs.any? { |rj| job["name"] == rj["name"] &&
              job["version"].to_s == rj["version"].to_s }
            say("SKIP".green)
            @skipped += 1
            FileUtils.rm_rf(File.join("jobs", "#{job["name"]}.tgz"))
          else
            say("UPLOAD".red)
          end
        end

        return nil if @skipped == 0
        `tar -czf #{repacked_path} . 2>&1`
        return repacked_path if $? == 0
      end
    end

    # If sparse release is allowed we bypass the requirement of having all jobs
    # and packages in place when we do validation. However for jobs and packages
    # that are present we still need to validate checksums
    def perform_validation(options = {})
      # CLEANUP this syntax
      allow_sparse = options.has_key?(:allow_sparse) ?
          !!options[:allow_sparse] :
          false

      step("File exists and readable",
           "Cannot find release file #{@tarball_path}", :fatal) do
        exists?
      end

      step("Extract tarball",
           "Cannot extract tarball #{@tarball_path}", :fatal) do
        unpack
      end

      manifest_file = File.expand_path("release.MF", @unpack_dir)

      step("Manifest exists", "Cannot find release manifest", :fatal) do
        File.exists?(manifest_file)
      end

      manifest = load_yaml_file(manifest_file)

      step("Release name/version",
           "Manifest doesn't contain release name and/or version") do
        manifest.is_a?(Hash) &&
            manifest.has_key?("name") &&
            manifest.has_key?("version")
      end

      @release_name = manifest["name"]
      @version = manifest["version"].to_s

      # Check packages
      total_packages = manifest["packages"].size
      available_packages = {}

      manifest["packages"].each_with_index do |package, i|
        @packages << package
        name, version = package['name'], package['version']

        package_file   = File.expand_path(name + ".tgz",
                                          @unpack_dir + "/packages")
        package_exists = File.exists?(package_file)

        step("Read package '%s' (%d of %d)" % [name, i+1, total_packages],
             "Missing package '#{name}'") do
          package_exists || allow_sparse
        end

        if package_exists
          available_packages[name] = true
          step("Package '#{name}' checksum",
               "Incorrect checksum for package '#{name}'") do
            Digest::SHA1.file(package_file).hexdigest == package["sha1"]
          end
        end
      end

      # Check package dependencies
      # Note that we use manifest["packages"] here; manifest contains
      # all packages even if release is sparse, so we can detect problems
      # even in sparse release tarball.
      if total_packages > 0
        step("Package dependencies",
             "Package dependencies couldn't be resolved") do
          begin
            tsort_packages(manifest["packages"].inject({}) { |h, p|
              h[p["name"]] = p["dependencies"] || []; h })
            true
          rescue Bosh::Cli::CircularDependency,
              Bosh::Cli::MissingDependency => e
            errors << e.message
            false
          end
        end
      end

      # Check jobs
      total_jobs = manifest["jobs"].size

      step("Checking jobs format",
           "Jobs are not versioned, please re-create release " +
               "with current CLI version (or any CLI >= 0.4.4)", :fatal) do
        total_jobs > 0 && manifest["jobs"][0].is_a?(Hash)
      end

      manifest["jobs"].each_with_index do |job, i|
        @jobs << job
        name    = job["name"]
        version = job["version"]

        job_file   = File.expand_path(name + ".tgz", @unpack_dir + "/jobs")
        job_exists = File.exists?(job_file)

        step("Read job '%s' (%d of %d), version %s" % [name, i+1, total_jobs,
                                                       version],
             "Job '#{name}' not found") do
          job_exists || allow_sparse
        end

        if job_exists
          step("Job '#{name}' checksum",
               "Incorrect checksum for job '#{name}'") do
            Digest::SHA1.file(job_file).hexdigest == job["sha1"]
          end

          job_tmp_dir = Dir.mktmpdir
          FileUtils.mkdir_p(job_tmp_dir)
          `tar -C #{job_tmp_dir} -xzf #{job_file} 2>&1`
          job_extracted = $?.exitstatus == 0

          step("Extract job '#{name}'", "Cannot extract job '#{name}'") do
            job_extracted
          end

          if job_extracted
            job_manifest_file = File.expand_path("job.MF", job_tmp_dir)
            if File.exists?(job_manifest_file)
              job_manifest = load_yaml_file(job_manifest_file)
            end
            job_manifest_valid = job_manifest.is_a?(Hash)

            step("Read job '#{name}' manifest",
                 "Invalid job '#{name}' manifest") do
              job_manifest_valid
            end

            if job_manifest_valid && job_manifest["templates"]
              job_manifest["templates"].each_key do |template|
                step("Check template '#{template}' for '#{name}'",
                     "No template named '#{template}' for '#{name}'") do
                  File.exists?(File.expand_path(template,
                                                job_tmp_dir + "/templates"))
                end
              end
            end

            if job_manifest_valid && job_manifest["packages"]
              job_manifest["packages"].each do |package_name|
                step("Job '#{name}' needs '#{package_name}' package",
                     "Job '#{name}' references missing package " +
                         "'#{package_name}'") do
                  available_packages[package_name] || allow_sparse
                end
              end
            end

            step("Monit file for '#{name}'",
                 "Monit script missing for job '#{name}'") do
              File.exists?(File.expand_path("monit", job_tmp_dir)) ||
                  Dir.glob("#{job_tmp_dir}/*.monit").size > 0
            end
          end
        end
      end

      print_info(manifest)
    end

    def print_info(manifest)
      say("\nRelease info")
      say("------------")

      say("Name:    #{manifest["name"]}")
      say("Version: #{manifest["version"]}")

      say("\nPackages")

      if manifest["packages"].empty?
        say("  - none")
      end

      for package in manifest["packages"]
        say("  - #{package["name"]} (#{package["version"]})")
      end

      say("\nJobs")

      if manifest["jobs"].empty?
        say("  - none")
      end

      for job in manifest["jobs"]
        say("  - #{job["name"]} (#{job["version"]})")
      end
    end

  end
end

