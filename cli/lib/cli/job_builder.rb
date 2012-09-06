# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  class JobBuilder
    include PackagingHelper

    attr_reader :name, :version, :packages, :templates,
                :release_dir, :built_packages, :tarball_path

    # @return [Hash] Properties defined in this job
    attr_reader :properties

    def self.run_prepare_script(script_path)
      unless File.exists?(script_path)
        raise InvalidJob, "Prepare script at `#{script_path}' doesn't exist"
      end

      unless File.executable?(script_path)
        raise InvalidJob, "Prepare script at `#{script_path}' is not executable"
      end

      old_env = ENV

      script_dir = File.dirname(script_path)
      script_name = File.basename(script_path)

      begin
        # We need to temporarily delete some rubygems related artefacts
        # because preparation scripts shouldn't share any assumptions
        # with CLI itself
        %w{ BUNDLE_GEMFILE RUBYOPT }.each { |key| ENV.delete(key) }

        output = nil
        Dir.chdir(script_dir) do
          cmd = "./#{script_name} 2>&1"
          output = `#{cmd}`
        end

        unless $?.exitstatus == 0
          raise InvalidJob, "`#{script_path}' script failed"
        end

        output
      ensure
        ENV.each_pair { |k, v| ENV[k] = old_env[k] }
      end
    end

    # @param [String] directory Release directory
    # @param [Hash] options Build options
    def self.discover(directory, options = {})
      builders = []

      Dir[File.join(directory, "jobs", "*")].each do |job_dir|
        next unless File.directory?(job_dir)
        job_dirname = File.basename(job_dir)

        prepare_script = File.join(job_dir, "prepare")
        if File.exists?(prepare_script)
          run_prepare_script(prepare_script)
        end

        job_spec = load_yaml_file(File.join(job_dir, "spec"))
        if job_spec["name"] != job_dirname
          raise InvalidJob,
                "Found `#{job_spec["name"]}' job in " +
                "`#{job_dirname}' directory, please fix it"
        end

        final = options[:final]
        dry_run = options[:dry_run]
        blobstore = options[:blobstore]
        package_names = options[:package_names]

        builder = new(job_spec, directory, final, blobstore, package_names)
        builder.dry_run = true if dry_run
        builders << builder
      end

      builders
    end

    def initialize(spec, release_dir, final, blobstore, built_packages = [])
      spec = load_yaml_file(spec) if spec.is_a?(String) && File.file?(spec)

      @name = spec["name"]
      @version = nil
      @tarball_path = nil
      @packages = spec["packages"].to_a
      @built_packages = built_packages.to_a
      @release_dir = release_dir
      @templates_dir = File.join(job_dir, "templates")
      @tarballs_dir = File.join(release_dir, "tmp", "jobs")
      @final = final
      @blobstore = blobstore
      @artefact_type = "job"

      case spec["templates"]
      when Hash
        @templates = spec["templates"].keys
      else
        raise InvalidJob, "Incorrect templates section in `#{@name}' " +
          "job spec (Hash expected, #{spec["properties"].class} given)"
      end

      if spec.has_key?("properties")
        if spec["properties"].is_a?(Hash)
          @properties = spec["properties"]
        else
          raise InvalidJob, "Incorrect properties section in `#{@name}' " +
            "job spec (Hash expected, #{spec["properties"].class} given)"
        end
      else
        @properties = {}
      end

      if @name.blank?
        raise InvalidJob, "Job name is missing"
      end

      if @templates.nil?
        raise InvalidJob, "Please include templates section with at least 1 " +
            "(possibly dummy) file into `#{@name}' job spec"
      end

      unless @name.bosh_valid_id?
        raise InvalidJob, "`#{@name}' is not a valid BOSH identifier"
      end

      unless File.exists?(File.join(job_dir, "spec"))
        raise InvalidJob, "Cannot find spec file for '#{name}'"
      end

      if missing_packages.size > 0
        raise InvalidJob, "Some packages required by '#{name}' job " +
            "are missing: %s" % [missing_packages.join(", ")]
      end

      if missing_templates.size > 0
        raise InvalidJob, "Some template files required by '#{name}' job " +
            "are missing: %s" % [missing_templates.join(", ")]
      end

      if extra_templates.size > 0
        raise InvalidJob, "There are unused template files for job " +
            "'#{name}': %s" % [extra_templates.join(", ")]
      end

      unless monit_files.size > 0
        raise InvalidJob, "Cannot find monit file for '#{name}'"
      end

      @dev_builds_dir = File.join(@release_dir, ".dev_builds", "jobs", @name)
      @final_builds_dir = File.join(@release_dir, ".final_builds",
                                    "jobs", @name)

      FileUtils.mkdir_p(job_dir)
      FileUtils.mkdir_p(@dev_builds_dir)
      FileUtils.mkdir_p(@final_builds_dir)

      init_indices
    end

    def copy_files
      FileUtils.mkdir_p(File.join(build_dir, "templates"))
      copied = 0

      templates.each do |template|
        src = File.join(@templates_dir, template)
        dst = File.join(build_dir, "templates", template)
        FileUtils.mkdir_p(File.dirname(dst))

        FileUtils.cp(src, dst, :preserve => true)
        copied += 1
      end

      monit_files.each do |file|
        FileUtils.cp(file, build_dir, :preserve => true)
        copied += 1
      end

      FileUtils.cp(File.join(job_dir, "spec"), File.join(build_dir, "job.MF"),
                   :preserve => true)
      copied += 1
      copied
    end

    def prepare_files
      File.join(job_dir, "prepare")
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

    def monit_files
      glob = File.join(job_dir, '*.monit')
      files = Dir.glob(glob)
      monit = File.join(job_dir, "monit")
      files << monit if File.exist?(monit)
      files
    end

    def reload
      @fingerprint = nil
      @build_dir   = nil
      self
    end

    # @return [Array<String>] Returns full paths of all templates in the job
    #   (regular job templates and monit)
    def all_templates
      regular_templates = @templates.map do |template|
        File.join(@templates_dir, template)
      end

      regular_templates.sort + monit_files
    end

    private

    def make_fingerprint
      contents = ""

      files = all_templates
      files << File.join(job_dir, "spec")

      files.each do |filename|
        path = File.basename(filename)
        digest = Digest::SHA1.file(filename).hexdigest
        contents << "%s%s%s" % [path, digest, tracked_permissions(filename)]
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

    def extra_templates
      return [] if !File.directory?(@templates_dir)

      Dir.chdir(@templates_dir) do
        Dir["**/*"].reject do |file|
          File.directory?(file) || templates.include?(file)
        end
      end
    end

    def in_build_dir(&block)
      Dir.chdir(build_dir) { yield }
    end

  end
end
