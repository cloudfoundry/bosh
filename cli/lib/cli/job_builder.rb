module Bosh::Cli
  class JobBuilder

    attr_reader :name, :version, :packages, :templates, :release_dir, :built_packages, :tarball_path

    def initialize(spec, release_dir, final, blobstore, built_packages = [])
      spec = YAML.load_file(spec) if spec.is_a?(String) && File.file?(spec)

      @name           = spec["name"]
      @packages       = spec["packages"]
      @built_packages = built_packages
      @release_dir    = release_dir
      @templates_dir  = File.join(job_dir, "templates")
      @tarballs_dir   = File.join(release_dir, "tmp", "jobs")
      @final          = final
      @blobstore      = blobstore

      @templates = \
      case spec["templates"]
      when Hash
        spec["templates"].keys
      else
        raise InvalidJob, "Incorrect templates section in `#{@name}' job spec (should resolve to a hash)"
      end

      if @name.blank?
        raise InvalidJob, "Job name is missing"
      end

      if @templates.nil?
        raise InvalidJob, "Please include templates section with at least 1 (possibly dummy) file into `#{@name}' job spec"
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

      if missing_templates.size > 0
        raise InvalidJob, "Some template files required by '#{name}' job are missing: %s" % [ missing_templates.join(", ")]
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

      @version = version
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
        true
      else
        say "Tarball for `#{name}' (dev version `#{version}') not found"
        nil
      end
    end

    def generate_tarball
      current_final = @final_jobs.latest_version.to_i

      if @dev_jobs.latest_version.to_s =~ /^(\d+)\.(\d+)/
        major, minor = $1.to_i, $2.to_i
        minor = major == current_final ? minor + 1 : 1
        major = current_final
      else
        major, minor = 0, 1
      end

      version  = "#{major}.#{minor}-dev"
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

      version = @final_jobs.latest_version.to_i + 1
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
      @version      = version
      true
    rescue Bosh::Blobstore::BlobstoreError => e
      raise InvalidJob, "Blobstore error: #{e}"
    end

    def copy_files
      FileUtils.mkdir_p(File.join(build_dir, "templates"))
      copied = 0

      templates.each do |template|
        FileUtils.cp(File.join(@templates_dir, template), File.join(build_dir, "templates"))
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

      # templates, monit, spec
      files = templates.map do |template|
        File.join(@templates_dir, template)
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

    def missing_templates
      templates.select do |template|
        !File.exists?(File.join(@templates_dir, template))
      end
    end

    def in_build_dir(&block)
      Dir.chdir(build_dir) { yield }
    end

  end
end
