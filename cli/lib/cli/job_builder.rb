module Bosh::Cli
  class JobBuilder
    include PackagingHelper

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

      @dev_builds_dir = File.join(@release_dir, ".dev_builds", "jobs", @name)
      @final_builds_dir = File.join(@release_dir, ".final_builds", "jobs", @name)

      FileUtils.mkdir_p(job_dir)
      FileUtils.mkdir_p(@dev_builds_dir)
      FileUtils.mkdir_p(@final_builds_dir)

      init_indices
    end

    def final?
      @final
    end

    def build
      use_final_version || use_dev_version || generate_tarball
      upload_tarball(@tarball_path) if final?
    end

    def copy_files
      FileUtils.mkdir_p(File.join(build_dir, "templates"))
      copied = 0

      templates.each do |template|
        FileUtils.cp(File.join(@templates_dir, template), File.join(build_dir, "templates"), :preserve => true)
        copied += 1
      end

      FileUtils.cp(File.join(job_dir, "monit"), build_dir, :preserve => true)
      FileUtils.cp(File.join(job_dir, "spec"), File.join(build_dir, "job.MF"), :preserve => true)
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
