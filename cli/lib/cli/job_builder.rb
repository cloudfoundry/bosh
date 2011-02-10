module Bosh::Cli
  class JobBuilder

    attr_reader :name, :version, :public_version, :packages, :configs, :release_dir, :built_packages, :tarball_path

    def initialize(spec, release_dir, final, blobstore, built_packages = [])
      spec = YAML.load_file(spec) if spec.is_a?(String) && File.file?(spec)

      @name           = spec["name"]
      @packages       = spec["packages"]
      @built_packages = built_packages
      @release_dir    = release_dir
      @configs_dir    = File.join(job_dir, "config")
      @tarballs_dir   = File.join(release_dir, "tmp", "jobs")
      @final          = final
      @blobstore      = blobstore

      @configs = \
      case spec["configuration"]
      when Hash
        spec["configuration"].keys
      else
        raise InvalidJob, "Incorrect configuration section in `#{@name}' job spec (should resolve to a hash)"
      end

      if @name.blank?
        raise InvalidJob, "Job name is missing"
      end

      if @configs.nil?
        raise InvalidJob, "Please include configuration section with at least 1 (possibly dummy) file into `#{@name}' job spec"
      end

      unless @name.bosh_valid_id?
        raise InvalidJob, "`#{@name}' is not a valid Bosh identifier"
      end

      unless File.exists?(File.join(job_dir, "spec"))
        raise InvalidJob, "Cannot find spec file for '#{name}'"
      end

      if missing_packages.size > 0
        raise InvalidJob, "Some packages required by '#{name}' job are missing: %s" % [ missing_packages.join(", ") ]
      end

      if missing_configs.size > 0
        raise InvalidJob, "Some config files required by '#{name}' job are missing: %s" % [ missing_configs.join(", ")]
      end

      unless File.exists?(File.join(job_dir, "monit"))
        raise InvalidJob, "Cannot find monit file for '#{name}'"
      end

      FileUtils.mkdir_p(dev_builds_dir)
      FileUtils.mkdir_p(final_builds_dir)

      @dev_jobs   = VersionsIndex.new(dev_builds_dir)
      @final_jobs = VersionsIndex.new(final_builds_dir)
    end

    def final?
      @final
    end

    def checksum
      if @tarball_path && File.exists?(@tarball_path)
        Digest::SHA1.hexdigest(File.read(@tarball_path))
      else
        raise RuntimeError, "cannot read checksum for not yet generated job"
      end
    end

    def build
      use_final_version || use_dev_version || generate_tarball
      upload_tarball(@tarball_path) if final?
    end

    def use_final_version
      say "Looking for final version of `#{name}'"
      job_attrs = @final_jobs[fingerprint]

      if job_attrs.nil?
        say "Final version of `#{name}' not found"
        return nil
      end

      blobstore_id = job_attrs["blobstore_id"]
      version      = job_attrs["version"]

      if @final_jobs.version_exists?(version)
        say "Found final version `#{name}' (#{version}) in local cache"
        @tarball_path = @final_jobs.filename(version)
      else
        say "Fetching `#{name}' (final version #{version}) from blobstore (#{blobstore_id})"
        payload = @blobstore.get(blobstore_id)
        @tarball_path = @final_jobs.add_version(fingerprint, job_attrs, payload)
      end

      @version = @public_version = version
      true
    rescue Bosh::Blobstore::NotFound => e
      raise InvalidJob, "Final version of `#{name}' not found in blobstore"
    rescue Bosh::Blobstore::BlobstoreError => e
      raise InvalidJob, "Blobstore error: #{e}"
    end

    def use_dev_version
      say "Looking for dev version of `#{name}'"
      job_attrs = @dev_jobs[fingerprint]

      if job_attrs.nil?
        say "Dev version of `#{name}' not found"
        return nil
      end

      version = job_attrs["version"]

      if @dev_jobs.version_exists?(version)
        say "Found dev version `#{name}' (#{version})"
        @tarball_path   = @dev_jobs.filename(version)
        @version        = version
        @public_version = "#{version}_dev"
        true
      else
        say "Tarball for `#{name}' (dev version `#{version}') not found"
        nil
      end
    end

    def generate_tarball
      job_attrs = @dev_jobs[fingerprint]

      version  = \
      if job_attrs.nil?
        @dev_jobs.next_version
      else
        job_attrs["version"]
      end

      tmp_file = Tempfile.new(name)

      say "Generating `#{name}' (dev version #{version})"

      copy_files

      in_build_dir do
        tar_out = `tar -czf #{tmp_file.path} . 2>&1`
        raise InvalidPackage, "Cannot create job tarball: #{tar_out}" unless $?.exitstatus == 0
      end

      payload = tmp_file.read

      job_attrs = {
        "version" => version,
        "sha1"    => Digest::SHA1.hexdigest(payload)
      }

      @dev_jobs.add_version(fingerprint, job_attrs, payload)
      @tarball_path   = @dev_jobs.filename(version)
      @version        = version
      @public_version = "#{version}_dev"

      say "Generated `#{name}' (dev version #{version}): `#{@tarball_path}'"
      true
    end

    def upload_tarball(path)
      job_attrs = @final_jobs[fingerprint]

      if !job_attrs.nil?
        version = job_attrs["version"]
        say "`#{name}' (final version #{version}) already uploaded"
        return
      end

      version = @final_jobs.next_version
      payload = File.read(path)

      say "Uploading `#{path}' as `#{name}' (final version #{version})"

      blobstore_id = @blobstore.create(payload)

      job_attrs = {
        "blobstore_id" => blobstore_id,
        "sha1"         => Digest::SHA1.hexdigest(payload),
        "version"      => version
      }

      say "`#{name}' (final version #{version}) uploaded, blobstore id #{blobstore_id}"
      @final_jobs.add_version(fingerprint, job_attrs, payload)
      @tarball_path = @final_jobs.filename(version)
      @version      = @public_version = version
      true
    rescue Bosh::Blobstore::BlobstoreError => e
      raise InvalidJob, "Blobstore error: #{e}"
    end

    def copy_files
      FileUtils.mkdir_p(File.join(build_dir, "config"))
      copied = 0

      configs.each do |config|
        FileUtils.cp(File.join(@configs_dir, config), File.join(build_dir, "config"))
        copied += 1
      end

      FileUtils.cp(File.join(job_dir, "monit"), build_dir)
      FileUtils.cp(File.join(job_dir, "spec"), File.join(build_dir, "job.MF"))
      copied += 2
      copied
    end

    def build_dir
      @build_dir ||= Dir.mktmpdir
    end

    def job_dir
      File.join(@release_dir, "jobs", @name)
    end

    def dev_builds_dir
      File.join(@release_dir, ".dev_builds", "jobs", name)
    end

    def final_builds_dir
      File.join(@release_dir, ".final_builds", "jobs", name)
    end

    def fingerprint
      @fingerprint ||= make_fingerprint
    end

    def reload
      @fingerprint = nil
      @build_dir   = nil
      self
    end

    private

    def make_fingerprint
      contents = ""

      # configs, monit, spec
      files = configs.map do |config|
        File.join(@configs_dir, config)
      end.sort

      files << File.join(job_dir, "monit")
      files << File.join(job_dir, "spec")

      files.each do |filename|
        contents << "%s%s%s" % [ File.basename(filename), File.read(filename), File.stat(filename).mode.to_s(8) ]
      end

      Digest::SHA1.hexdigest(contents)
    end

    def missing_packages
      @missing_packages ||= packages - built_packages
    end

    def missing_configs
      configs.select do |config|
        !File.exists?(File.join(@configs_dir, config))
      end
    end

    def in_build_dir(&block)
      Dir.chdir(build_dir) { yield }
    end

  end
end
