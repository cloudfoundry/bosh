module Bosh::Cli
  class ReleaseTarball
    include Validation
    include DependencyHelper

    attr_reader :release_name, :jobs, :packages, :version
    attr_reader :skipped, :unpack_dir # Mostly for tests

    def initialize(tarball_path)
      @tarball_path = File.expand_path(tarball_path, Dir.pwd)
      @unpack_dir   = Dir.mktmpdir
      @jobs = []
      @packages = []

      if compiled_release?
        @packages_folder = "compiled_packages"
      else
        @packages_folder = "packages"
      end
    end

    # Unpacks tarball to @unpack_dir, returns true if succeeded, false if failed
    def unpack
      return @unpacked unless @unpacked.nil?
      exit_success = system("tar", "-C", @unpack_dir, "-xzf", @tarball_path, out: "/dev/null", err: "/dev/null")
      @unpacked = !!exit_success
    end

    # Creates a new tarball from the current contents of @unpack_dir
    def create_from_unpacked(target_path)
      raise "Not unpacked yet!" unless @unpacked
      !!system("tar", "-C", @unpack_dir, "-pczf", File.expand_path(target_path), ".", out: "/dev/null", err: "/dev/null")
    end

    def exists?
      File.exists?(@tarball_path) && File.readable?(@tarball_path)
    end

    def manifest
      return nil unless valid?
      unpack
      File.read(File.join(@unpack_dir, "release.MF"))
    end

    def compiled_release?
      unpack
      File.exists?(File.expand_path("compiled_packages", @unpack_dir))
    end

    def replace_manifest(hash)
      return nil unless valid?
      unpack
      write_yaml(hash, File.join(@unpack_dir, "release.MF"))
    end

    def job_tarball_path(name)
      return nil unless valid?
      unpack
      File.join(@unpack_dir, 'jobs', "#{name}.tgz")
    end

    def package_tarball_path(name)
      return nil unless valid?
      unpack
      File.join(@unpack_dir, 'packages', "#{name}.tgz")
    end

    def license_resource
      return nil unless valid?
      unpack
      return Resources::License.new(@unpack_dir)
    end

    def convert_to_old_format
      step('Converting to old format',
           "Cannot extract tarball #{@tarball_path}", :fatal) do
        unpack
      end

      manifest_file = File.expand_path('release.MF', @unpack_dir)
      manifest = load_yaml_file(manifest_file)
      old_format_version = Bosh::Common::Version::ReleaseVersion.parse(manifest['version']).to_old_format
      manifest['version'] = old_format_version
      write_yaml(manifest, manifest_file)
      tmpdir = Dir.mktmpdir
      repacked_path = File.join(tmpdir, 'release-reformat.tgz')

      Dir.chdir(@unpack_dir) do
        exit_success = system("tar", "-czf", repacked_path, ".", out: "/dev/null", err: "/dev/null")
        return repacked_path if exit_success
      end
    end

    # Repacks tarball according to the structure of remote release
    # Return path to repackaged tarball or nil if repack has failed
    def repack(package_matches = [])
      return nil unless valid?
      unpack

      tmpdir = Dir.mktmpdir
      repacked_path = File.join(tmpdir, "release-repack.tgz")

      manifest = load_yaml_file(File.join(@unpack_dir, "release.MF"))

      local_packages = manifest[@packages_folder]
      local_jobs = manifest["jobs"]

      @skipped = 0

      Dir.chdir(@unpack_dir) do
        local_packages.each do |package|
          say("#{package["name"]} (#{package["version"]})".ljust(30), " ")

          if  package_matches and package_matches.include?(package["sha1"]) ||
             (package["fingerprint"] &&
              package_matches.include?(package["fingerprint"]))
            say("SKIP".make_green)
            @skipped += 1
            FileUtils.rm_rf(File.join("packages", "#{package["name"]}.tgz"))
          else
            say("UPLOAD".make_red)
          end
        end

        local_jobs.each do |job|
          say("#{job["name"]} (#{job["version"]})".ljust(30), " ")
          say("UPLOAD".make_red)
        end

        return nil if @skipped == 0
        exit_success = system("tar", "-czf", repacked_path, ".", out: "/dev/null", err: "/dev/null")
        return repacked_path if exit_success
      end
    end

    # If sparse release is allowed we bypass the requirement of having all jobs
    # and packages in place when we do validation. However for jobs and packages
    # that are present we still need to validate checksums
    def perform_validation(options = {})
      allow_sparse = options.fetch(:allow_sparse, false)
      should_print_release_info = options.fetch(:print_release_info, true)

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
      total_packages = manifest[@packages_folder].size
      available_packages = {}

      manifest[@packages_folder].each_with_index do |package, i|
        @packages << package
        name, version = package['name'], package['version']

        package_file   = File.expand_path(name + ".tgz", File.join(@unpack_dir, @packages_folder))
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
            tsort_packages(manifest[@packages_folder].inject({}) { |h, p|
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
          job_extracted = !!system("tar", "-C", job_tmp_dir, "-xzf", job_file, out: "/dev/null", err: "/dev/null")

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

      print_info(manifest) if should_print_release_info
    end

    class TarballArtifact
      def initialize(info)
        @name = info['name']
        @version = info['version']
      end

      attr_reader :name, :version

      def new_version?
        false
      end
    end

    def license
      m = Psych.load(manifest)
      license = m['license']
      return nil if !license
      license['name'] = 'license'
      TarballArtifact.new(license)
    end

    def packages
      m = Psych.load(manifest)
      packages = m['packages'] || []
      packages.map { |pkg| TarballArtifact.new(pkg) }
    end

    def jobs
      m = Psych.load(manifest)
      jobs = m['jobs'] || []
      jobs.map { |job| TarballArtifact.new(job) }
    end

    def affected_jobs
      []
    end

    def print_info(manifest)
      say("\nRelease info")
      say("------------")

      say("Name:    #{manifest["name"]}")
      say("Version: #{manifest["version"]}")

      say("\nPackages")

      if manifest[@packages_folder].empty?
        say("  - none")
      end

      for package in manifest[@packages_folder]
        say("  - #{package["name"]} (#{package["version"]})")
      end

      say("\nJobs")

      if manifest["jobs"].empty?
        say("  - none")
      end

      for job in manifest["jobs"]
        say("  - #{job["name"]} (#{job["version"]})")
      end

      say("\nLicense")
      if manifest["license"].nil? || manifest["license"].empty?
        say("  - none")
      else
        say("  - license (#{manifest["license"]["version"]})")
      end
    end
  end
end

